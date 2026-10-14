import Foundation

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

  var sourceURL: URL {
    URL(string: "https://fdc.nal.usda.gov/food-details/\(fdcID)/nutrients")!
  }

  var dataType: String { "Foundation" }
  var release: String { "2026-04-30" }
  var attribution: String { "USDA FoodData Central · Foundation Foods · April 2026" }

  var energyMethod: String {
    switch energyNutrientID {
    case 2048: "USDA Atwater specific factors"
    case 2047: "USDA Atwater general factors"
    default: "USDA reported energy"
    }
  }

  var isValid: Bool {
    fdcID > 0 && id == "usda-foundation:\(fdcID)"
      && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !publicationDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && [1008, 2047, 2048].contains(energyNutrientID)
      && nutritionPer100g.isValidPer100g
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
