import Foundation

enum FoodCatalogSourceType: String, Codable, Sendable {
  case foundation = "Foundation"
  case srLegacy = "SR Legacy"

  var idPrefix: String { self == .foundation ? "usda-foundation:" : "usda-sr-legacy:" }
  var release: String { self == .foundation ? "2026-04-30" : "2018-04" }
  var shortLabel: String {
    self == .foundation ? "USDA Foundation · 2026" : "USDA SR Legacy · 2018"
  }
  var attribution: String {
    self == .foundation
      ? "USDA FoodData Central · Foundation Foods · April 2026"
      : "USDA FoodData Central · SR Legacy · April 2018 (historical reference)"
  }

  static func contains(key: String) -> Bool {
    [Self.foundation, .srLegacy].contains { source in
      guard key.hasPrefix(source.idPrefix) else { return false }
      let suffix = key.dropFirst(source.idPrefix.count)
      return !suffix.isEmpty && suffix.utf8.allSatisfy { (48...57).contains($0) }
        && Int(suffix).map { $0 > 0 && String($0) == suffix } == true
    }
  }
}

/// A weight USDA supplies for this exact food and preparation. A cup of one
/// food never supplies the weight of a cup of another food.
struct FoodCatalogServing: Codable, Equatable, Identifiable, Sendable {
  let id: String
  let label: String
  let gramWeight: Double

  var isValid: Bool {
    !id.isEmpty && !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && label.count <= 300 && gramWeight.isFinite && gramWeight > 0 && gramWeight <= 1_000_000
  }
}

/// Nutrients for 100 grams of the edible food, in the preparation shown in its
/// name. These are USDA values, not a guess based on a household-sized serving.
struct FoodCatalogNutrition: Codable, Equatable, Sendable {
  let calories: Double
  let proteinGrams: Double
  let carbGrams: Double
  let fatGrams: Double

  var isValidPer100g: Bool {
    calories.isFinite && (0...1000).contains(calories)
      && [proteinGrams, carbGrams, fatGrams].allSatisfy {
        $0.isFinite && (0...100).contains($0)
      }
  }

  /// Retains all available precision. Display formatting happens in the UI.
  func scaled(toGrams grams: Double) throws -> FoodCatalogNutrition {
    guard isValidPer100g else { throw FoodCatalogError.invalidData }
    guard grams.isFinite, grams > 0 else { throw FoodCatalogError.invalidPortion }
    let factor = grams / 100
    guard factor > 0 else { throw FoodCatalogError.invalidPortion }
    let result = FoodCatalogNutrition(
      calories: calories * factor,
      proteinGrams: proteinGrams * factor,
      carbGrams: carbGrams * factor,
      fatGrams: fatGrams * factor
    )
    guard
      [result.calories, result.proteinGrams, result.carbGrams, result.fatGrams]
        .allSatisfy({ $0.isFinite && $0 >= 0 })
    else { throw FoodCatalogError.invalidPortion }
    return result
  }
}

/// An immutable search result. It is deliberately separate from SwiftData's
/// FoodItem so browsing never inserts or changes a person's saved foods.
struct FoodCatalogEntry: Codable, Equatable, Identifiable, Sendable {
  let id: String
  let fdcID: Int
  let name: String
  /// Publication date as supplied by USDA; the catalog release is separate.
  let publicationDate: String
  let energyNutrientID: Int
  let nutritionPer100g: FoodCatalogNutrition
  let sourceType: FoodCatalogSourceType
  let category: String
  let servings: [FoodCatalogServing]

  init(
    id: String, fdcID: Int, name: String, publicationDate: String, energyNutrientID: Int,
    nutritionPer100g: FoodCatalogNutrition, sourceType: FoodCatalogSourceType = .foundation,
    category: String = "", servings: [FoodCatalogServing] = []
  ) {
    self.id = id
    self.fdcID = fdcID
    self.name = name
    self.publicationDate = publicationDate
    self.energyNutrientID = energyNutrientID
    self.nutritionPer100g = nutritionPer100g
    self.sourceType = sourceType
    self.category = category
    self.servings = servings
  }

  private enum CodingKeys: String, CodingKey {
    case id, fdcID, name, publicationDate, energyNutrientID, nutritionPer100g
    case sourceType, category, servings
  }

  /// Accepts the original Foundation-only fixture without changing its IDs.
  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    fdcID = try values.decode(Int.self, forKey: .fdcID)
    name = try values.decode(String.self, forKey: .name)
    publicationDate = try values.decode(String.self, forKey: .publicationDate)
    energyNutrientID = try values.decode(Int.self, forKey: .energyNutrientID)
    nutritionPer100g = try values.decode(FoodCatalogNutrition.self, forKey: .nutritionPer100g)
    sourceType =
      try values.decodeIfPresent(FoodCatalogSourceType.self, forKey: .sourceType) ?? .foundation
    category = try values.decodeIfPresent(String.self, forKey: .category) ?? ""
    servings = try values.decodeIfPresent([FoodCatalogServing].self, forKey: .servings) ?? []
  }

  var sourceURL: URL {
    URL(string: "https://fdc.nal.usda.gov/food-details/\(fdcID)/nutrients")!
  }

  var dataType: String { sourceType.rawValue }
  var release: String { sourceType.release }
  var attribution: String { sourceType.attribution }

  var energyMethod: String {
    switch energyNutrientID {
    case 2048: "USDA Atwater specific factors"
    case 2047: "USDA Atwater general factors"
    default: "USDA reported energy"
    }
  }

  var isValid: Bool {
    fdcID > 0 && id == "\(sourceType.idPrefix)\(fdcID)"
      && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !publicationDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && [1008, 2047, 2048].contains(energyNutrientID)
      && nutritionPer100g.isValidPer100g
      && servings.count <= 100 && servings.allSatisfy(\.isValid)
      && Set(servings.map(\.id)).count == servings.count
  }

  /// Returns a personal, editable copy; the read-only source remains intact.
  /// The source ID and weight stay visible in its existing serving field, so
  /// saving a diary item does not require a persistent schema migration.
  @MainActor
  func makeFoodItem(grams: Double = 100) throws -> FoodItem {
    guard isValid else { throw FoodCatalogError.invalidData }
    let nutrition = try nutritionPer100g.scaled(toGrams: grams)
    return FoodItem(
      name: name,
      calories: nutrition.calories,
      proteinGrams: nutrition.proteinGrams,
      carbGrams: nutrition.carbGrams,
      fatGrams: nutrition.fatGrams,
      servingDescription: "\(NutritionInput.format(grams)) g · USDA FDC \(fdcID)"
    )
  }
}

enum FoodCatalogError: LocalizedError, Equatable {
  case unavailable
  case invalidData
  case invalidPortion

  var errorDescription: String? {
    switch self {
    case .unavailable:
      "The offline food catalog could not be opened. You can enter a food manually."
    case .invalidData:
      "The offline food catalog could not be verified. You can enter a food manually."
    case .invalidPortion: "Enter a weight greater than zero."
    }
  }
}

/// Keeps search interchangeable while allowing the review screen to show the
/// original basis and source before the result becomes an editable FoodItem.
@MainActor
protocol FoodCatalogProviding {
  func catalogSearch(query: String, limit: Int) throws -> [FoodCatalogEntry]
  func catalogEntry(id: String) throws -> FoodCatalogEntry?
  var foodCount: Int { get throws }
}
