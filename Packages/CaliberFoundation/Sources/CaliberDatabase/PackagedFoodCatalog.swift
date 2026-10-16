import CryptoKit
import Foundation
import GRDB

/// A public, immutable packaged-food reference. Nutrients use 100 units of `basisUnit`.
/// A milliliter basis is never converted to grams without a source density measurement.
public struct PackagedCatalogProduct: Equatable, Sendable {
  public let gtin14: String
  public let fdcID: Int
  public let name: String
  public let brand: String
  public let publicationDate: String
  public let modifiedDate: String
  public let calories: Double
  public let proteinGrams: Double
  public let carbGrams: Double
  public let fatGrams: Double
  public let basisUnit: String
  public let servingQuantity: Double?
  public let servingUnit: String?
  /// Original household text, when supplied. It does not establish a gram or volume conversion.
  public let servingLabel: String?
  public let source: ReferenceCatalogSource

  public init(
    gtin14: String, fdcID: Int, name: String, brand: String, publicationDate: String,
    modifiedDate: String, calories: Double, proteinGrams: Double, carbGrams: Double,
    fatGrams: Double, basisUnit: String, servingQuantity: Double?, servingUnit: String?,
    servingLabel: String?, source: ReferenceCatalogSource
  ) {
    self.gtin14 = gtin14
    self.fdcID = fdcID
    self.name = name
    self.brand = brand
    self.publicationDate = publicationDate
    self.modifiedDate = modifiedDate
    self.calories = calories
    self.proteinGrams = proteinGrams
    self.carbGrams = carbGrams
    self.fatGrams = fatGrams
    self.basisUnit = basisUnit
    self.servingQuantity = servingQuantity
    self.servingUnit = servingUnit
    self.servingLabel = servingLabel
    self.source = source
  }
}

/// Safe presentation errors never expose a database path, barcode query or SQL statement.
public enum PackagedFoodCatalogError: LocalizedError, Equatable, Sendable {
  case unavailable
  case invalidData

  public var errorDescription: String? {
    switch self {
    case .unavailable:
      "The offline barcode database could not be opened. You can enter food manually."
    case .invalidData:
      "The offline barcode database could not be verified. You can enter food manually."
    }
  }
}

/// A pinned USDA Branded snapshot. GRDB serializes reads; no migration, network or user-data
/// operation is available through this API. The app's editable diary remains a separate store.
public final class PackagedFoodCatalog: Sendable {
  private let queue: DatabaseQueue
  private let source: ReferenceCatalogSource
  private static let maximumFileBytes = 40 * 1_024 * 1_024
  private static let sourceID = "usda-branded:2026-04"

  public init(url: URL, expectedSHA256: String) throws {
    guard url.isFileURL, Self.isSHA256(expectedSHA256) else {
      throw PackagedFoodCatalogError.invalidData
    }
    do {
      let values = try url.resourceValues(forKeys: [
        .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
      ])
      guard values.isRegularFile == true, values.isSymbolicLink != true,
        let size = values.fileSize, (100...Self.maximumFileBytes).contains(size),
        !["-wal", "-shm", "-journal"].contains(where: {
          FileManager.default.fileExists(atPath: url.path + $0)
        })
      else { throw PackagedFoodCatalogError.invalidData }
      let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
      // Reject WAL-format files before SQLite can attempt to open or create their sidecars.
      guard bytes.count == size, bytes[18] == 1, bytes[19] == 1,
        Self.digest(bytes) == expectedSHA256
      else { throw PackagedFoodCatalogError.invalidData }
      var configuration = Configuration()
      configuration.readonly = true
      configuration.prepareDatabase { db in
        try db.execute(
          sql: "PRAGMA query_only=ON; PRAGMA trusted_schema=OFF; PRAGMA foreign_keys=ON")
      }
      let opened = try DatabaseQueue(path: url.path, configuration: configuration)
      let validatedSource = try opened.read { db in try Self.validate(db) }
      // A changed file must not inherit the verification of the original pinned bytes.
      guard Self.digest(try Data(contentsOf: url, options: .mappedIfSafe)) == expectedSHA256 else {
        throw PackagedFoodCatalogError.invalidData
      }
      queue = opened
      source = validatedSource
    } catch let error as PackagedFoodCatalogError {
      throw error
    } catch {
      if !FileManager.default.fileExists(atPath: url.path) {
        throw PackagedFoodCatalogError.unavailable
      }
      throw PackagedFoodCatalogError.invalidData
    }
  }

  public var foodCount: Int {
    get throws {
      try safeRead { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM packaged_products") ?? 0
      }
    }
  }

  /// Callers normalize UPC/EAN variants before lookup. This key must be a checksum-valid GTIN14.
  public func product(gtin14: String) throws -> PackagedCatalogProduct? {
    guard Self.isGTIN14(gtin14) else { return nil }
    return try safeRead { db in
      guard
        let row = try Row.fetchOne(
          db, sql: "SELECT * FROM packaged_products WHERE gtin14=?", arguments: [gtin14])
      else { return nil }
      return try Self.product(row, source: source)
    }
  }

  private func safeRead<T>(_ body: (Database) throws -> T) throws -> T {
    do { return try queue.read(body) } catch { throw PackagedFoodCatalogError.invalidData }
  }

  private static func validate(_ db: Database) throws -> ReferenceCatalogSource {
    try validateSchema(db)
    guard try Int.fetchOne(db, sql: "PRAGMA application_id") == 1_128_352_848,
      try Int.fetchOne(db, sql: "PRAGMA user_version") == 1,
      try String.fetchOne(db, sql: "PRAGMA journal_mode") == "delete",
      try String.fetchAll(db, sql: "PRAGMA integrity_check") == ["ok"],
      try Row.fetchAll(db, sql: "PRAGMA foreign_key_check").isEmpty,
      try String.fetchOne(
        db, sql: "SELECT value FROM packaged_metadata WHERE key='schema_version'") == "1",
      try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM packaged_sources") == 1,
      let sourceRow = try Row.fetchOne(db, sql: "SELECT * FROM packaged_sources"),
      let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM packaged_products"),
      (1...50_000).contains(count),
      try Int.fetchOne(
        db, sql: "SELECT COUNT(*) FROM packaged_products WHERE typeof(fdc_id)!='integer'") == 0
    else { throw PackagedFoodCatalogError.invalidData }
    let source = try ReferenceCatalogSource(
      id: sourceRow.decode(forColumn: "id"), name: sourceRow.decode(forColumn: "name"),
      dataType: sourceRow.decode(forColumn: "data_type"),
      release: sourceRow.decode(forColumn: "release"),
      archiveURL: sourceRow.decode(forColumn: "archive_url"),
      archiveSHA256: sourceRow.decode(forColumn: "archive_sha256"),
      license: sourceRow.decode(forColumn: "license"))
    guard source.id == sourceID, source.name == "USDA FoodData Central",
      source.dataType == "Branded", source.release == "2026-04", source.license == "CC0-1.0",
      source.archiveURL
        == "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_branded_food_csv_2026-04-30.zip",
      source.archiveSHA256 == "26050a5d03197469813754743a21ee0fad4ccf22b6aac2a995846a987719fc49"
    else { throw PackagedFoodCatalogError.invalidData }
    var gtins: Set<String> = []
    var foodIDs: Set<Int> = []
    let rows = try Row.fetchCursor(db, sql: "SELECT * FROM packaged_products")
    while let row = try rows.next() {
      let item = try product(row, source: source)
      let itemSource = try row.decode(String.self, forColumn: "source_id")
      let isVolume = item.basisUnit == "mL"
      let calorieLimit = isVolume ? 2_000.0 : 1_000.0
      let macroLimit = isVolume ? 200.0 : 100.0
      guard isGTIN14(item.gtin14), gtins.insert(item.gtin14).inserted,
        item.fdcID > 0, foodIDs.insert(item.fdcID).inserted, itemSource == source.id,
        bounded(item.name, maximum: 1_000), bounded(item.brand, maximum: 500, allowEmpty: true),
        canonicalDate(item.publicationDate),
        item.modifiedDate.isEmpty || canonicalDate(item.modifiedDate),
        ["g", "mL"].contains(item.basisUnit), item.servingUnit == item.basisUnit,
        let quantity = item.servingQuantity, quantity.isFinite, quantity > 0, quantity <= 10_000,
        item.servingLabel.map({ bounded($0, maximum: 300) }) ?? true,
        item.calories.isFinite, (0...calorieLimit).contains(item.calories),
        [item.proteinGrams, item.carbGrams, item.fatGrams].allSatisfy({
          $0.isFinite && (0...macroLimit).contains($0)
        })
      else { throw PackagedFoodCatalogError.invalidData }
    }
    return source
  }

  private static func validateSchema(_ db: Database) throws {
    let tables = Set(
      try String.fetchAll(
        db, sql: "SELECT name FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%'"))
    guard tables == ["packaged_metadata", "packaged_sources", "packaged_products"],
      try Int.fetchOne(
        db, sql: "SELECT COUNT(*) FROM sqlite_schema WHERE type IN ('view','trigger')") == 0,
      try Int.fetchOne(
        db,
        sql: """
          SELECT COUNT(*) FROM pragma_foreign_key_list('packaged_products')
          WHERE "table"='packaged_sources' AND "from"='source_id' AND ("to"='id' OR "to" IS NULL)
          """) == 1
    else { throw PackagedFoodCatalogError.invalidData }
    for (table, key) in [
      ("packaged_metadata", "key"), ("packaged_sources", "id"), ("packaged_products", "gtin14"),
    ] {
      let columns = try Row.fetchAll(
        db, sql: "SELECT name,pk FROM pragma_table_info(?)", arguments: [table])
      let primaryKeys = try columns.filter { try $0.decode(Int.self, forColumn: "pk") > 0 }
        .map { try $0.decode(String.self, forColumn: "name") }
      guard primaryKeys == [key] else { throw PackagedFoodCatalogError.invalidData }
    }
  }

  private static func product(_ row: Row, source: ReferenceCatalogSource) throws
    -> PackagedCatalogProduct
  {
    try PackagedCatalogProduct(
      gtin14: row.decode(forColumn: "gtin14"), fdcID: row.decode(forColumn: "fdc_id"),
      name: row.decode(forColumn: "name"), brand: row.decode(forColumn: "brand"),
      publicationDate: row.decode(forColumn: "publication_date"),
      modifiedDate: row.decode(forColumn: "modified_date"),
      calories: row.decode(forColumn: "calories"), proteinGrams: row.decode(forColumn: "protein_g"),
      carbGrams: row.decode(forColumn: "carbohydrate_g"), fatGrams: row.decode(forColumn: "fat_g"),
      basisUnit: row.decode(forColumn: "basis_unit"),
      servingQuantity: row.decode(forColumn: "serving_quantity"),
      servingUnit: row.decode(forColumn: "serving_unit"),
      servingLabel: row.decode(forColumn: "serving_label"),
      source: source)
  }

  private static func isGTIN14(_ value: String) -> Bool {
    let digits = Array(value.utf8)
    guard digits.count == 14, digits.allSatisfy({ (48...57).contains($0) }),
      digits.contains(where: { $0 != 48 })
    else { return false }
    let total = digits.enumerated().reduce(0) { result, pair in
      result + Int(pair.element - 48) * (pair.offset.isMultiple(of: 2) ? 3 : 1)
    }
    return total.isMultiple(of: 10)
  }

  private static func bounded(_ value: String, maximum: Int, allowEmpty: Bool = false) -> Bool {
    (allowEmpty || !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      && value.count <= maximum
      && value.utf8.count <= maximum * 4
      && !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
  }

  private static func canonicalDate(_ value: String) -> Bool {
    let bytes = Array(value.utf8)
    guard bytes.count == 10, bytes[4] == 45, bytes[7] == 45,
      bytes.enumerated().allSatisfy({
        $0.offset == 4 || $0.offset == 7 || (48...57).contains($0.element)
      }),
      let year = Int(value.prefix(4)), year > 0,
      let month = Int(value.dropFirst(5).prefix(2)), (1...12).contains(month),
      let day = Int(value.suffix(2)), day > 0
    else { return false }
    let leap = year.isMultiple(of: 4) && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
    let days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    return day <= days[month - 1]
  }

  private static func isSHA256(_ value: String) -> Bool {
    value.utf8.count == 64
      && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
  }

  private static func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}
