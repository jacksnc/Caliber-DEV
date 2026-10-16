import Foundation
import SwiftData
import Testing

@testable import Caliber__DEV_

@MainActor @Suite("Expanded offline food database")
struct ExpandedFoodDatabaseTests {
  @Test("All original Foundation IDs and nutrient values survive the indexed import")
  func originalFoodsUnchanged() throws {
    struct OriginalCatalog: Decodable { let foods: [FoodCatalogEntry] }
    let url = try #require(Bundle.main.url(forResource: "FoodCatalog", withExtension: "json"))
    let original = try JSONDecoder().decode(OriginalCatalog.self, from: Data(contentsOf: url))
    let service = BundledFoodSearchService()
    #expect(original.foods.count == 311)
    for before in original.foods {
      let after = try #require(try service.catalogEntry(id: before.id))
      #expect(after.name == before.name && after.fdcID == before.fdcID)
      #expect(after.nutritionPer100g == before.nutritionPer100g)
      #expect(after.energyNutrientID == before.energyNutrientID)
      #expect(after.publicationDate == before.publicationDate)
      #expect(after.sourceType == .foundation)
    }
  }

  @Test("Legacy foods carry historical attribution and keep preparations distinct")
  func historicalSourceAndPreparation() throws {
    let service = BundledFoodSearchService()
    let rice = try #require(try service.catalogEntry(id: "usda-sr-legacy:168878"))
    #expect(rice.name == "Rice, white, long-grain, regular, enriched, cooked")
    #expect(rice.dataType == "SR Legacy" && rice.release == "2018-04")
    #expect(rice.attribution.contains("historical"))
    #expect(rice.nutritionPer100g.calories == 130)
    #expect(FoodNutritionReference.usda(rice).sourceNote.contains("not a current restaurant menu"))
    #expect(
      try service.catalogSearch(query: "rice raw", limit: 200).allSatisfy {
        $0.name.contains("raw")
      })
    #expect(try service.catalogEntry(id: "usda-foundation:168878") == nil)
  }

  @Test("Two cooked-rice cups use the stated 158 gram measure exactly once")
  func householdMeasureScalingAndSnapshot() throws {
    let service = BundledFoodSearchService()
    let rice = try #require(try service.catalogEntry(id: "usda-sr-legacy:168878"))
    let cup = try #require(rice.servings.first { $0.label == "1 cup" })
    #expect(cup.gramWeight == 158)
    let selection = try FoodPortionMath.resolve(
      value: 2, unit: .portions, basisGrams: cup.gramWeight)
    #expect(selection.grams == 316 && selection.quantity == 1)
    let reference = FoodNutritionReference.usda(rice)
    let total = try reference.portionTotals(grams: selection.grams)
    #expect(abs(total.calories - 410.8) < 1e-10)
    #expect(abs(total.protein - 8.5004) < 1e-10)
    let container = try ModelContainer(
      for: FoodItem.self, DiaryEntry.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let entry = try ReferenceFoodLogger.log(
      reference: reference, grams: selection.grams,
      enteredPortionDescription: "2 × 1 cup", date: .now, meal: .lunch,
      in: ModelContext(container))
    #expect(abs(entry.calories - 410.8) < 1e-10 && entry.quantity == 1)
    #expect(entry.foodItem?.servingDescription.contains("316 g (2 × 1 cup)") == true)
    entry.foodItem?.calories = 450
    #expect(rice.nutritionPer100g.calories == 130)
    #expect(try service.catalogEntry(id: rice.id)?.nutritionPer100g.calories == 130)
  }

  @Test("A two-tablespoon source measure already includes both tablespoons")
  func compoundMeasureNotDoubled() throws {
    let peanutButter = try #require(
      try BundledFoodSearchService().catalogEntry(id: "usda-sr-legacy:172470"))
    let serving = try #require(peanutButter.servings.first { $0.label == "2 tbsp" })
    #expect(serving.gramWeight == 32)
    let mass = try FoodPortionMath.resolve(
      value: 1, unit: .portions, basisGrams: serving.gramWeight)
    #expect(mass.grams == 32)
    #expect(
      abs(
        try FoodNutritionReference.usda(peanutButter).portionTotals(grams: mass.grams).calories
          - 191.36) < 1e-10)
  }

  @Test("Portion choice conversion keeps mass and fractional measures")
  func fractionalMeasuresAndInvalidWeights() throws {
    let grams = try FoodPortionMath.resolve(value: 0.5, unit: .portions, basisGrams: 158)
    #expect(grams.grams == 79)
    #expect(try FoodPortionMath.amount(grams: 79, unit: .grams, basisGrams: 100) == 79)
    #expect(try FoodPortionMath.amount(grams: 79, unit: .portions, basisGrams: 158) == 0.5)
    for mass in [0.0, -1, .nan, .infinity] {
      #expect(!FoodCatalogServing(id: "fixture", label: "1 cup", gramWeight: mass).isValid)
    }
    #expect(!FoodCatalogServing(id: "fixture", label: " ", gramWeight: 158).isValid)
  }

  @Test("Legacy favorites reopen alongside existing Foundation favorites")
  func legacyFavoritesPreserveExistingKeys() throws {
    let suite = "Caliber.Database.Favorites.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = FoodLibraryPreferences(defaults: defaults)
    #expect(preferences.setFavorite(true, for: "usda-foundation:2346396"))
    #expect(preferences.setFavorite(true, for: "usda-sr-legacy:168878"))
    #expect(!preferences.setFavorite(true, for: "usda-sr-legacy:0168878"))
    #expect(!preferences.setFavorite(true, for: "usda-sr-legacy:0"))
    let reopened = FoodLibraryPreferences(defaults: defaults)
    #expect(reopened.favoriteKeys == ["usda-foundation:2346396", "usda-sr-legacy:168878"])
  }
}
