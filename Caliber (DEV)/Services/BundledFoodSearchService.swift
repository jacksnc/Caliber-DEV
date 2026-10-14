import Foundation

/// All queries run locally against a checked-in USDA CC0 dataset. No account,
/// API key, location, or network request is needed to search or view a result.
@MainActor
struct BundledFoodSearchService: FoodSearchService, FoodCatalogProviding {
  private let catalog: Result<FoodCatalogDocument, FoodCatalogError>

  init(bundle: Bundle = .main) {
    guard let url = bundle.url(forResource: "FoodCatalog", withExtension: "json"),
      let data = try? Data(contentsOf: url)
    else {
      catalog = .failure(.unavailable)
      return
    }
    catalog = Self.decode(data)
  }

  /// Data injection is for offline fixtures and corrupted-resource tests.
  init(data: Data) {
    catalog = Self.decode(data)
  }

  var foodCount: Int {
    get throws { try catalog.get().foods.count }
  }

  func catalogEntry(id: String) throws -> FoodCatalogEntry? {
    try catalog.get().foods.first { $0.id == id }
  }

  func catalogSearch(query: String, limit: Int = 50) throws -> [FoodCatalogEntry] {
    let foods = try catalog.get().foods
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
      && foods.allSatisfy(\.isValid) && Set(foods.map(\.id)).count == foods.count
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
