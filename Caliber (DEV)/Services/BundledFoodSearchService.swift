import CaliberDatabase
import Foundation

/// All queries run locally against a checked-in USDA CC0 dataset. No account,
/// API key, location, or network request is needed to search or view a result.
@MainActor
struct BundledFoodSearchService: FoodSearchService, FoodCatalogProviding {
  private enum Storage {
    case database(ReferenceFoodCatalog)
    case fixture(FoodCatalogDocument)
  }
  private let catalog: Result<Storage, FoodCatalogError>
  // Reuse one validated read-only connection as SwiftUI recreates views.
  private static var production: Result<Storage, FoodCatalogError>?
  private static var pending: Task<Result<ReferenceFoodCatalog, ReferenceFoodCatalogError>, Never>?

  init(bundle: Bundle = .main) {
    if bundle.bundleURL == Bundle.main.bundleURL {
      let result = Self.production ?? Self.openDatabase(bundle: bundle)
      Self.production = result
      catalog = result
    } else {
      catalog = Self.openDatabase(bundle: bundle)
    }
  }

  private init(catalog: Result<Storage, FoodCatalogError>) { self.catalog = catalog }

  /// The full resource check runs off the UI thread. Concurrent screens share
  /// the same load; the database remains read-only after it is ready.
  static func prepared() async -> Self {
    if let production { return Self(catalog: production) }
    if pending == nil {
      guard let input = input(bundle: .main) else {
        return Self(catalog: .failure(.unavailable))
      }
      let url = input.0
      let hash = input.1.databaseSHA256
      let foods = input.1.foodCount
      let servings = input.1.servingCount
      pending = Task.detached(priority: .userInitiated) {
        Self.readDatabase(url: url, hash: hash, foods: foods, servings: servings)
      }
    }
    guard let pending else { return Self(catalog: .failure(.unavailable)) }
    let result = await pending.value.map(Storage.database).mapError { _ in
      FoodCatalogError.invalidData
    }
    production = result
    return Self(catalog: result)
  }

  private static func input(bundle: Bundle) -> (URL, FoodDatabaseManifest)? {
    guard let url = bundle.url(forResource: "FoodDatabase", withExtension: "sqlite"),
      let manifestURL = bundle.url(forResource: "FoodDatabaseManifest", withExtension: "json"),
      let size = try? manifestURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
      (1...100_000).contains(size),
      let data = try? Data(contentsOf: manifestURL), data.count <= 100_000,
      let manifest = try? JSONDecoder().decode(FoodDatabaseManifest.self, from: data),
      manifest.schemaVersion == 1, (1...50_000).contains(manifest.foodCount),
      (0...100_000).contains(manifest.servingCount)
    else { return nil }
    return (url, manifest)
  }

  private static func openDatabase(bundle: Bundle) -> Result<Storage, FoodCatalogError> {
    guard let (url, manifest) = input(bundle: bundle) else { return .failure(.unavailable) }
    return readDatabase(
      url: url, hash: manifest.databaseSHA256,
      foods: manifest.foodCount, servings: manifest.servingCount
    ).map(Storage.database).mapError { _ in FoodCatalogError.invalidData }
  }

  nonisolated private static func readDatabase(url: URL, hash: String, foods: Int, servings: Int)
    -> Result<ReferenceFoodCatalog, ReferenceFoodCatalogError>
  {
    do {
      let database = try ReferenceFoodCatalog(url: url, expectedSHA256: hash)
      guard try database.foodCount == foods, try database.servingCount == servings
      else { return .failure(.invalidData) }
      return .success(database)
    } catch { return .failure(.invalidData) }
  }

  /// Data injection is for offline fixtures and corrupted-resource tests.
  init(data: Data) {
    catalog = Self.decode(data).map(Storage.fixture)
  }

  var foodCount: Int {
    get throws {
      switch try catalog.get() {
      case .database(let database): return try database.foodCount
      case .fixture(let document): return document.foods.count
      }
    }
  }

  func catalogEntry(id: String) throws -> FoodCatalogEntry? {
    switch try catalog.get() {
    case .database(let database): return try database.entry(id: id).map(Self.entry)
    case .fixture(let document): return document.foods.first { $0.id == id }
    }
  }

  func catalogSearch(query: String, limit: Int = 50) throws -> [FoodCatalogEntry] {
    let foods: [FoodCatalogEntry]
    switch try catalog.get() {
    case .database(let database):
      return try database.search(query: query, limit: limit).map(Self.entry)
    case .fixture(let document): foods = document.foods
    }
    guard limit > 0 else { return [] }
    let queryWords = Self.words(query)
    guard !queryWords.isEmpty else { return Array(foods.prefix(min(limit, 200))) }
    let queryPhrase = queryWords.joined(separator: " ")
    let matches = foods.compactMap { food -> (FoodCatalogEntry, Int)? in
      let nameWords = Self.words(food.name)
      guard queryWords.allSatisfy({ query in nameWords.contains { $0.hasPrefix(query) } })
      else { return nil }
      let namePhrase = nameWords.joined(separator: " ")
      // Exact words outrank prefix-only matches (egg before eggplant).
      // Word order is optional, so "Greek yogurt" finds "Yogurt, Greek".
      let exactWords = queryWords.filter { nameWords.contains($0) }.count
      var score = exactWords * 10
      if namePhrase == queryPhrase {
        score += 1000
      } else if namePhrase.hasPrefix(queryPhrase) {
        score += 200
      } else if namePhrase.contains(queryPhrase) {
        score += 100
      }
      return (food, score)
    }
    return matches.sorted { lhs, rhs in
      if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
      let lhsName = Self.words(lhs.0.name).joined(separator: " ")
      let rhsName = Self.words(rhs.0.name).joined(separator: " ")
      return lhsName == rhsName ? lhs.0.fdcID < rhs.0.fdcID : lhsName < rhsName
    }
    .prefix(min(limit, 200)).map(\.0)
  }

  func search(query: String) async throws -> [FoodItem] {
    try Task.checkCancellation()
    let matches = try catalogSearch(query: query)
    return try matches.map { try $0.makeFoodItem() }
  }

  private static func entry(_ food: ReferenceCatalogFood) throws -> FoodCatalogEntry {
    guard let type = FoodCatalogSourceType(rawValue: food.source.dataType) else {
      throw FoodCatalogError.invalidData
    }
    let entry = FoodCatalogEntry(
      id: food.id, fdcID: food.fdcID, name: food.name, publicationDate: food.publicationDate,
      energyNutrientID: food.energyNutrientID,
      nutritionPer100g: FoodCatalogNutrition(
        calories: food.calories, proteinGrams: food.proteinGrams,
        carbGrams: food.carbGrams, fatGrams: food.fatGrams),
      sourceType: type, category: food.category,
      servings: food.servings.map {
        FoodCatalogServing(id: $0.id, label: $0.label, gramWeight: $0.gramWeight)
      })
    guard entry.isValid else { throw FoodCatalogError.invalidData }
    return entry
  }

  private static func words(_ value: String) -> [String] {
    value.folding(
      options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
      locale: Locale(identifier: "en_US_POSIX")
    )
    .lowercased(with: Locale(identifier: "en_US_POSIX"))
    .components(separatedBy: CharacterSet.alphanumerics.inverted)
    .filter { !$0.isEmpty }
  }

  private static func decode(_ data: Data) -> Result<FoodCatalogDocument, FoodCatalogError> {
    guard data.count <= 1_000_000,
      let document = try? JSONDecoder().decode(FoodCatalogDocument.self, from: data),
      document.isValid
    else { return .failure(.invalidData) }
    return .success(document)
  }
}

private struct FoodCatalogDocument: Decodable {
  let schemaVersion: Int
  let source: FoodCatalogSource
  let foods: [FoodCatalogEntry]

  var isValid: Bool {
    schemaVersion == 1 && source.isValid && !foods.isEmpty && foods.count <= 10_000
      && foods.allSatisfy({ $0.isValid && $0.sourceType == .foundation })
      && Set(foods.map(\.id)).count == foods.count
  }
}

private struct FoodCatalogSource: Decodable {
  let name: String
  let dataType: String
  let release: String
  let archiveURL: String
  let archiveSHA256: String
  let license: String
  let basisGrams: Double

  var isValid: Bool {
    name == "USDA FoodData Central" && dataType == "Foundation" && release == "2026-04-30"
      && archiveURL
        == "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_json_2026-04-30.zip"
      && archiveSHA256 == "186e988ec542e913f51ef62b86a47758e8cdd0d1dc3889e7b055581f3c09c77a"
      && license == "CC0-1.0" && basisGrams == 100
  }
}

private struct FoodDatabaseManifest: Decodable {
  let schemaVersion: Int
  let databaseSHA256: String
  let foodCount: Int
  let servingCount: Int
}
