import CryptoKit
import Foundation
import GRDB

/// Public food data stays separate from editable personal foods and the live diary store.
public struct ReferenceCatalogSource: Equatable, Sendable {
  public let id: String
  public let name: String
  public let dataType: String
  public let release: String
  public let archiveURL: String
  public let archiveSHA256: String
  public let license: String

  public init(
    id: String, name: String, dataType: String, release: String, archiveURL: String,
    archiveSHA256: String, license: String
  ) {
    self.id = id
    self.name = name
    self.dataType = dataType
    self.release = release
    self.archiveURL = archiveURL
    self.archiveSHA256 = archiveSHA256
    self.license = license
  }
}

public struct ReferenceCatalogServing: Equatable, Sendable {
  public let id: String
  public let label: String
  public let gramWeight: Double

  public init(id: String, label: String, gramWeight: Double) {
    self.id = id
    self.label = label
    self.gramWeight = gramWeight
  }
}

/// Nutrient values use a 100 g basis; a source serving is an explicit measured gram weight.
public struct ReferenceCatalogFood: Equatable, Sendable {
  public let id: String
  public let fdcID: Int
  public let name: String
  public let publicationDate: String
  public let energyNutrientID: Int
  public let calories: Double
  public let proteinGrams: Double
  public let carbGrams: Double
  public let fatGrams: Double
  public let category: String
  public let source: ReferenceCatalogSource
  public let servings: [ReferenceCatalogServing]

  public init(
    id: String, fdcID: Int, name: String, publicationDate: String, energyNutrientID: Int,
    calories: Double, proteinGrams: Double, carbGrams: Double, fatGrams: Double,
    category: String, source: ReferenceCatalogSource, servings: [ReferenceCatalogServing]
  ) {
    self.id = id
    self.fdcID = fdcID
    self.name = name
    self.publicationDate = publicationDate
    self.energyNutrientID = energyNutrientID
    self.calories = calories
    self.proteinGrams = proteinGrams
    self.carbGrams = carbGrams
    self.fatGrams = fatGrams
    self.category = category
    self.source = source
    self.servings = servings
  }
}

/// Errors contain no SQL, source paths or private user information.
public enum ReferenceFoodCatalogError: LocalizedError, Equatable, Sendable {
  case unavailable
  case invalidData

  public var errorDescription: String? {
    switch self {
    case .unavailable: "The offline food database could not be opened. You can enter food manually."
    case .invalidData:
      "The offline food database could not be verified. You can enter food manually."
    }
  }
}

/// Opens a pinned, bundled SQLite file read-only. No migrations, user records or network access.
/// GRDB serializes synchronous reads; the queue is Sendable and no mutable catalog state escapes.
public final class ReferenceFoodCatalog: Sendable {
  private let queue: DatabaseQueue
  private let sources: [String: ReferenceCatalogSource]
  private static let maximumFileBytes = 20 * 1_024 * 1_024
  private static let locale = Locale(identifier: "en_US_POSIX")

  public init(url: URL, expectedSHA256: String) throws {
    guard url.isFileURL, Self.isSHA256(expectedSHA256) else {
      throw ReferenceFoodCatalogError.invalidData
    }
    do {
      let values = try url.resourceValues(forKeys: [
        .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
      ])
      guard values.isRegularFile == true, values.isSymbolicLink != true,
        let size = values.fileSize, size > 0, size <= Self.maximumFileBytes,
        !["-wal", "-shm", "-journal"].contains(where: {
          FileManager.default.fileExists(atPath: url.path + $0)
        })
      else { throw ReferenceFoodCatalogError.invalidData }
      let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
      guard bytes.count == size, Self.digest(bytes) == expectedSHA256 else {
        throw ReferenceFoodCatalogError.invalidData
      }
      var configuration = Configuration()
      configuration.readonly = true
      configuration.prepareDatabase { db in
        // These are connection settings, never file mutations.
        try db.execute(
          sql: "PRAGMA query_only=ON; PRAGMA trusted_schema=OFF; PRAGMA foreign_keys=ON")
      }
      let opened = try DatabaseQueue(path: url.path, configuration: configuration)
      let validatedSources = try opened.read { db in try Self.validate(db) }
      // Fail closed if the file changed between checking the pin and opening its connection.
      guard Self.digest(try Data(contentsOf: url, options: .mappedIfSafe)) == expectedSHA256 else {
        throw ReferenceFoodCatalogError.invalidData
      }
      queue = opened
      sources = validatedSources
    } catch let error as ReferenceFoodCatalogError {
      throw error
    } catch {
      if !FileManager.default.fileExists(atPath: url.path) {
        throw ReferenceFoodCatalogError.unavailable
      }
      throw ReferenceFoodCatalogError.invalidData
    }
  }

  public var foodCount: Int {
    get throws {
      try safeRead { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM catalog_foods") ?? 0 }
    }
  }

  public var servingCount: Int {
    get throws {
      try safeRead { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM catalog_servings") ?? 0 }
    }
  }

  /// Primary-key lookup never walks the food list.
  public func entry(id: String) throws -> ReferenceCatalogFood? {
    guard Self.isFoodID(id) else { return nil }
    return try safeRead { db in
      let rows = try Row.fetchAll(
        db, sql: "SELECT * FROM catalog_foods WHERE id=?", arguments: [id])
      return try materialize(rows, db: db).first
    }
  }

  /// Every query token must match a word prefix. FTS syntax is never taken from the user.
  public func search(query: String, limit: Int = 50) throws -> [ReferenceCatalogFood] {
    guard limit > 0, query.utf8.count <= 512 else { return [] }
    let tokens = Self.words(query)
    guard tokens.count <= 16, tokens.allSatisfy({ $0.utf8.count <= 64 }) else { return [] }
    let maximum = min(limit, 200)
    return try safeRead { db in
      let rows: [Row]
      if tokens.isEmpty {
        rows = try Row.fetchAll(
          db,
          sql: """
            SELECT * FROM catalog_foods
            ORDER BY search_name, CASE source_id WHEN 'usda-foundation:2026-04-30' THEN 0 ELSE 1 END, fdc_id, id
            LIMIT ?
            """, arguments: [maximum])
      } else {
        let phrase = tokens.joined(separator: " ")
        let exactWordScores = Array(
          repeating: "(instr(' ' || f.search_name || ' ', ?) > 0)", count: tokens.count
        )
        .joined(separator: " + ")
        // Tokens are only Unicode letters/numbers, but quotes are still escaped before FTS use.
        let match = tokens.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"*" }
          .joined(separator: " AND ")
        var arguments = StatementArguments(tokens.map { " " + $0 + " " })
        arguments += [phrase, phrase + " %", "%" + phrase + "%", match, maximum]
        rows = try Row.fetchAll(
          db,
          sql: """
            SELECT f.*, ((\(exactWordScores)) * 10 + CASE
              WHEN f.search_name = ? THEN 1000
              WHEN f.search_name LIKE ? THEN 200
              WHEN f.search_name LIKE ? THEN 100 ELSE 0 END) AS relevance
            FROM food_search JOIN catalog_foods f ON f.id=food_search.food_id
            WHERE food_search MATCH ?
            ORDER BY relevance DESC,
              CASE f.source_id WHEN 'usda-foundation:2026-04-30' THEN 0 ELSE 1 END, f.search_name, f.fdc_id, f.id
            LIMIT ?
            """, arguments: arguments)
      }
      return try materialize(rows, db: db)
    }
  }

  private func safeRead<T>(_ body: (Database) throws -> T) throws -> T {
    do { return try queue.read(body) } catch { throw ReferenceFoodCatalogError.invalidData }
  }

  /// One batched serving query for up to 200 results, avoiding a query per food.
  private func materialize(_ rows: [Row], db: Database) throws -> [ReferenceCatalogFood] {
    guard !rows.isEmpty else { return [] }
    let ids = try rows.map { try $0.decode(String.self, forColumn: "id") }
    let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
    let servingRows = try Row.fetchAll(
      db,
      sql:
        "SELECT * FROM catalog_servings WHERE food_id IN (\(placeholders)) ORDER BY food_id,sort_order,id",
      arguments: StatementArguments(ids))
    var servings: [String: [ReferenceCatalogServing]] = [:]
    for row in servingRows {
      let foodID = try row.decode(String.self, forColumn: "food_id")
      servings[foodID, default: []].append(try Self.serving(row))
    }
    return try rows.map { row in
      let sourceID = try row.decode(String.self, forColumn: "source_id")
      guard let source = sources[sourceID] else { throw ReferenceFoodCatalogError.invalidData }
      let id = try row.decode(String.self, forColumn: "id")
      return try Self.food(row, source: source, servings: servings[id] ?? [])
    }
  }

  private static func validate(_ db: Database) throws -> [String: ReferenceCatalogSource] {
    try validateSchema(db)
    guard try Int.fetchOne(db, sql: "PRAGMA application_id") == 1_128_352_838,
      try Int.fetchOne(db, sql: "PRAGMA user_version") == 1,
      try String.fetchOne(db, sql: "PRAGMA journal_mode") == "delete",
      try String.fetchAll(db, sql: "PRAGMA integrity_check") == ["ok"],
      try Row.fetchAll(db, sql: "PRAGMA foreign_key_check").isEmpty,
      try String.fetchOne(db, sql: "SELECT value FROM catalog_metadata WHERE key='schema_version'")
        == "1",
      let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM catalog_foods"),
      (1...50_000).contains(count),
      let servingCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM catalog_servings"),
      (0...100_000).contains(servingCount),
      let sourceCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM catalog_sources"),
      (1...2).contains(sourceCount)
    else { throw ReferenceFoodCatalogError.invalidData }
    var sources: [String: ReferenceCatalogSource] = [:]
    for row in try Row.fetchAll(db, sql: "SELECT * FROM catalog_sources") {
      let source = try source(row)
      guard sourceIsValid(source), sources.updateValue(source, forKey: source.id) == nil else {
        throw ReferenceFoodCatalogError.invalidData
      }
    }
    var foodIDs: Set<String> = []
    var fdcIDs: Set<Int> = []
    for row in try Row.fetchAll(db, sql: "SELECT * FROM catalog_foods") {
      let sourceID = try row.decode(String.self, forColumn: "source_id")
      guard let source = sources[sourceID] else { throw ReferenceFoodCatalogError.invalidData }
      let item = try food(row, source: source, servings: [])
      let searchName = try row.decode(String.self, forColumn: "search_name")
      guard item.fdcID > 0, item.id == source.id.components(separatedBy: ":")[0] + ":\(item.fdcID)",
        foodIDs.insert(item.id).inserted, fdcIDs.insert(item.fdcID).inserted,
        bounded(item.name, maximum: 1_000), bounded(item.category, maximum: 300),
        bounded(item.publicationDate, maximum: 40), !words(item.name).isEmpty,
        searchName == words(item.name).joined(separator: " "),
        [1008, 2047, 2048].contains(item.energyNutrientID),
        item.calories.isFinite, (0...1_000).contains(item.calories),
        [item.proteinGrams, item.carbGrams, item.fatGrams].allSatisfy({
          $0.isFinite && (0...100).contains($0)
        })
      else { throw ReferenceFoodCatalogError.invalidData }
    }
    var servingIDs: Set<String> = []
    for row in try Row.fetchAll(db, sql: "SELECT * FROM catalog_servings") {
      let item = try serving(row)
      let foodID = try row.decode(String.self, forColumn: "food_id")
      let order = try row.decode(Int.self, forColumn: "sort_order")
      guard servingIDs.insert(item.id).inserted, bounded(item.id, maximum: 300),
        foodIDs.contains(foodID), bounded(item.label, maximum: 300),
        item.gramWeight.isFinite, item.gramWeight > 0, item.gramWeight <= 1_000_000,
        (0...100_000).contains(order)
      else { throw ReferenceFoodCatalogError.invalidData }
    }
    // Require exactly one FTS document per food, with the same searchable words.
    guard try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM food_search") == count,
      try Int.fetchOne(db, sql: "SELECT COUNT(DISTINCT food_id) FROM food_search") == count,
      try Int.fetchOne(
        db,
        sql: """
          SELECT COUNT(*) FROM food_search s LEFT JOIN catalog_foods f ON f.id=s.food_id
          WHERE f.id IS NULL OR s.name IS NULL OR s.name!=f.search_name
          """) == 0
    else { throw ReferenceFoodCatalogError.invalidData }
    return sources
  }

  private static func validateSchema(_ db: Database) throws {
    let tables = Set(
      try String.fetchAll(
        db, sql: "SELECT name FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%'"))
    let expected: Set<String> = [
      "catalog_metadata", "catalog_sources", "catalog_foods", "catalog_servings", "food_search",
      "food_search_data", "food_search_idx", "food_search_content", "food_search_docsize",
      "food_search_config",
    ]
    guard tables == expected,
      try Int.fetchOne(
        db, sql: "SELECT COUNT(*) FROM sqlite_schema WHERE type IN ('view','trigger')") == 0,
      let searchSQL = try String.fetchOne(
        db, sql: "SELECT sql FROM sqlite_schema WHERE name='food_search'"),
      searchSQL.lowercased().filter({ !$0.isWhitespace })
        == "createvirtualtablefood_searchusingfts5(food_idunindexed,name,tokenize='unicode61remove_diacritics2',prefix='234')"
    else { throw ReferenceFoodCatalogError.invalidData }
    for (table, key) in [
      ("catalog_metadata", "key"), ("catalog_sources", "id"), ("catalog_foods", "id"),
      ("catalog_servings", "id"),
    ] {
      let columns = try Row.fetchAll(
        db, sql: "SELECT name,pk FROM pragma_table_info(?)", arguments: [table])
      let primaryKeys = try columns.filter { try $0.decode(Int.self, forColumn: "pk") > 0 }
        .map { try $0.decode(String.self, forColumn: "name") }
      guard primaryKeys == [key] else { throw ReferenceFoodCatalogError.invalidData }
    }
    // Keep keyed lookups and batched servings bounded as the reference dataset grows.
    for (table, prefix) in [
      ("catalog_foods", ["search_name"]), ("catalog_servings", ["food_id", "sort_order", "id"]),
    ] {
      let indexes = try Row.fetchAll(
        db,
        sql: """
          SELECT i.name AS index_name,p.name AS column_name FROM pragma_index_list(?) i
          JOIN pragma_index_info(i.name) p WHERE i.partial=0 ORDER BY i.name,p.seqno
          """, arguments: [table])
      var columns: [String: [String]] = [:]
      for row in indexes {
        let index = try row.decode(String.self, forColumn: "index_name")
        columns[index, default: []].append(try row.decode(String.self, forColumn: "column_name"))
      }
      guard columns.values.contains(where: { Array($0.prefix(prefix.count)) == prefix }) else {
        throw ReferenceFoodCatalogError.invalidData
      }
    }
  }

  private static func source(_ row: Row) throws -> ReferenceCatalogSource {
    try ReferenceCatalogSource(
      id: row.decode(forColumn: "id"), name: row.decode(forColumn: "name"),
      dataType: row.decode(forColumn: "data_type"), release: row.decode(forColumn: "release"),
      archiveURL: row.decode(forColumn: "archive_url"),
      archiveSHA256: row.decode(forColumn: "archive_sha256"),
      license: row.decode(forColumn: "license"))
  }

  private static func serving(_ row: Row) throws -> ReferenceCatalogServing {
    try ReferenceCatalogServing(
      id: row.decode(forColumn: "id"), label: row.decode(forColumn: "label"),
      gramWeight: row.decode(forColumn: "gram_weight"))
  }

  private static func food(
    _ row: Row, source: ReferenceCatalogSource, servings: [ReferenceCatalogServing]
  ) throws -> ReferenceCatalogFood {
    try ReferenceCatalogFood(
      id: row.decode(forColumn: "id"), fdcID: row.decode(forColumn: "fdc_id"),
      name: row.decode(forColumn: "name"),
      publicationDate: row.decode(forColumn: "publication_date"),
      energyNutrientID: row.decode(forColumn: "energy_nutrient_id"),
      calories: row.decode(forColumn: "calories"),
      proteinGrams: row.decode(forColumn: "protein_g"),
      carbGrams: row.decode(forColumn: "carbohydrate_g"),
      fatGrams: row.decode(forColumn: "fat_g"), category: row.decode(forColumn: "category"),
      source: source, servings: servings)
  }

  private static func sourceIsValid(_ source: ReferenceCatalogSource) -> Bool {
    guard source.name == "USDA FoodData Central", source.license == "CC0-1.0" else { return false }
    switch source.id {
    case "usda-foundation:2026-04-30":
      return source.dataType == "Foundation" && source.release == "2026-04-30"
        && source.archiveURL
          == "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_json_2026-04-30.zip"
        && source.archiveSHA256
          == "186e988ec542e913f51ef62b86a47758e8cdd0d1dc3889e7b055581f3c09c77a"
    case "usda-sr-legacy:2018-04":
      return source.dataType == "SR Legacy" && source.release == "2018-04"
        && source.archiveURL
          == "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_json_2018-04.zip"
        && source.archiveSHA256
          == "0fe8ae486a2c8eb42cb96413f058deb51863a46c8fb8eeb4b1fb45006dd338ef"
    default: return false
    }
  }

  private static func words(_ value: String) -> [String] {
    value.decomposedStringWithCompatibilityMapping.folding(
      options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: locale
    )
    .lowercased(with: locale).components(separatedBy: CharacterSet.alphanumerics.inverted)
    .filter { !$0.isEmpty }
  }

  private static func bounded(_ value: String, maximum: Int) -> Bool {
    !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= maximum
      && !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
  }

  private static func isFoodID(_ id: String) -> Bool {
    guard id.utf8.count <= 80, let colon = id.firstIndex(of: ":") else { return false }
    let prefix = String(id[..<colon])
    let number = String(id[id.index(after: colon)...])
    return ["usda-foundation", "usda-sr-legacy"].contains(prefix)
      && Int(number).map { $0 > 0 && String($0) == number } == true
  }

  private static func isSHA256(_ value: String) -> Bool {
    value.utf8.count == 64
      && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
  }

  private static func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}
