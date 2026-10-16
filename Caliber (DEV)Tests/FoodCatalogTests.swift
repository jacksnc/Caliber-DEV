import Foundation
import Testing

@testable import Caliber__DEV_

@MainActor
@Suite("Offline USDA food catalog")
struct FoodCatalogTests {
  @Test("The production bundle contains 8,104 complete foods and traceable IDs")
  func bundledCatalog() throws {
    let service = BundledFoodSearchService()
    #expect(try service.foodCount == 8104)
    let oats = try #require(try service.catalogEntry(id: "usda-foundation:2346396"))
    #expect(
      oats.sourceURL.absoluteString == "https://fdc.nal.usda.gov/food-details/2346396/nutrients")
    #expect(oats.release == "2026-04-30")
    #expect(oats.dataType == "Foundation")
    #expect(oats.attribution.contains("USDA"))
    #expect(try service.catalogEntry(id: "unknown:2346396") == nil)
  }

  @Test("Actual USDA macro values retain the edible 100 gram basis")
  func publishedValues() throws {
    let service = BundledFoodSearchService()
    let chicken = try #require(try service.catalogEntry(id: "usda-foundation:331960"))
    #expect(chicken.name.contains("cooked, braised"))
    #expect(
      chicken.nutritionPer100g
        == FoodCatalogNutrition(calories: 166, proteinGrams: 32.1, carbGrams: 0, fatGrams: 3.24))
    let banana = try #require(try service.catalogEntry(id: "usda-foundation:1105314"))
    #expect(
      banana.nutritionPer100g
        == FoodCatalogNutrition(calories: 97, proteinGrams: 0.74, carbGrams: 23, fatGrams: 0.29))
    let oats = try #require(try service.catalogEntry(id: "usda-foundation:2346396"))
    #expect(oats.energyNutrientID == 2048)
    #expect(oats.nutritionPer100g.calories == 379)
    #expect(oats.energyMethod == "USDA Atwater specific factors")
    // The source also reports 382 general-factor kcal. We keep its
    // specific-factor value rather than recomputing rounded macro energy.
  }

  @Test("A 150 gram cooked portion makes an editable copy without changing its source")
  func portionAndCopy() throws {
    let service = BundledFoodSearchService()
    let chicken = try #require(try service.catalogEntry(id: "usda-foundation:331960"))
    let food = try chicken.makeFoodItem(grams: 150)
    #expect(food.calories == 249)
    #expect(abs(food.proteinGrams - 48.15) < 0.00000001)
    #expect(food.carbGrams == 0)
    #expect(abs(food.fatGrams - 4.86) < 0.00000001)
    #expect(food.servingDescription.contains("150 g"))
    #expect(food.servingDescription.contains("USDA FDC 331960"))
    food.calories = 260
    food.proteinGrams = 49
    #expect(chicken.nutritionPer100g.calories == 166)
    let next = try chicken.makeFoodItem()
    #expect(next.id != food.id)
    #expect(next.calories == 166)
  }

  @Test("Search accepts case, accents, punctuation, prefixes and words in any order")
  func normalizedSearch() throws {
    let service = BundledFoodSearchService()
    let ordinary = try service.catalogSearch(query: "greek yogurt", limit: 200)
    #expect(!ordinary.isEmpty)
    #expect(
      try ordinary.map(\.id)
        == service.catalogSearch(query: "  GRÉEK—YOGURT  ", limit: 200).map(\.id))
    #expect(
      ordinary.allSatisfy {
        $0.name.localizedCaseInsensitiveContains("Greek")
          && $0.name.localizedCaseInsensitiveContains("Yogurt")
      })
    #expect(
      try service.catalogSearch(query: "chicken breast cooked", limit: 200).contains {
        $0.fdcID == 331960
      })
    #expect(
      try service.catalogSearch(query: "banana", limit: 200).contains { $0.fdcID == 1_105_314 })
    #expect(try service.catalogSearch(query: "chicken grapefruit", limit: 200).isEmpty)
    #expect(try service.catalogSearch(query: "no such imaginary food", limit: 200).isEmpty)
  }

  @Test("Ranking favors an exact word over a longer prefix and is deterministic")
  func rankingAndLimits() throws {
    let service = BundledFoodSearchService()
    let eggs = try service.catalogSearch(query: "egg", limit: 200)
    let first = try #require(eggs.first)
    #expect(first.name.hasPrefix("Egg,"))
    #expect(eggs.contains { $0.name.hasPrefix("Eggplant,") })
    #expect(try eggs == service.catalogSearch(query: "egg", limit: 200))
    #expect(try service.catalogSearch(query: "", limit: 10).count == 10)
    #expect(try service.catalogSearch(query: " ", limit: -1).isEmpty)
    #expect(try service.catalogSearch(query: "", limit: 10_000).count == 200)
  }

  @Test("The compatibility protocol returns independent 100 gram food objects")
  func compatibilitySearch() async throws {
    let service: any FoodSearchService = BundledFoodSearchService()
    let foods = try await service.search(query: "oats rolled")
    let oats = try #require(foods.first)
    #expect(oats.calories == 379)
    #expect(oats.servingDescription.contains("100 g"))
    #expect(!oats.isSavedToLibrary)
    #expect(oats.menuItem == nil)
  }

  @Test("Missing, corrupt, duplicate or incorrectly based source data fails closed")
  func badResource() throws {
    #expect(throws: FoodCatalogError.invalidData) {
      try BundledFoodSearchService(data: Data("{}".utf8)).foodCount
    }
    for mutation in ["basis", "missing", "negative", "duplicate", "id", "energy"] {
      let data = try mutatedResource(mutation)
      #expect(throws: FoodCatalogError.invalidData) {
        try BundledFoodSearchService(data: data).catalogSearch(query: "banana")
      }
    }
  }

  @Test("Zero, negative, nonfinite and overflowing portions cannot become diary foods")
  func invalidPortionsAndOmissions() throws {
    let service = BundledFoodSearchService()
    let oats = try #require(try service.catalogEntry(id: "usda-foundation:2346396"))
    for grams in [0, -1, .nan, .infinity, .leastNonzeroMagnitude, .greatestFiniteMagnitude] {
      #expect(throws: FoodCatalogError.invalidPortion) { try oats.makeFoodItem(grams: grams) }
    }
    // No invented zero carbs for the source's negative-by-difference meat,
    // and no assumed protein/carbs for an incomplete olive oil record.
    #expect(try service.catalogEntry(id: "usda-foundation:2727566") == nil)
    #expect(try service.catalogEntry(id: "usda-foundation:748608") == nil)
  }

  private func mutatedResource(_ mutation: String) throws -> Data {
    let url = try #require(Bundle.main.url(forResource: "FoodCatalog", withExtension: "json"))
    var document = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    var source = try #require(document["source"] as? [String: Any])
    var foods = try #require(document["foods"] as? [[String: Any]])
    var food = foods[0]
    var nutrition = try #require(food["nutritionPer100g"] as? [String: Any])
    switch mutation {
    case "basis": source["basisGrams"] = 1
    case "missing": nutrition.removeValue(forKey: "proteinGrams")
    case "negative": nutrition["carbGrams"] = -1
    case "duplicate": foods.append(food)
    case "id": food["id"] = "unverified"
    case "energy": food["energyNutrientID"] = 1062  // kJ is not kcal.
    default: break
    }
    food["nutritionPer100g"] = nutrition
    foods[0] = food
    document["source"] = source
    document["foods"] = foods
    return try JSONSerialization.data(withJSONObject: document)
  }
}
