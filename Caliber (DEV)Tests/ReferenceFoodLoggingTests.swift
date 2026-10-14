import Foundation
import SwiftData
import Testing

@testable import Caliber__DEV_

@MainActor
private func referenceFixture() -> FoodNutritionReference {
  FoodNutritionReference(
    id: "fixture:1", name: "Fixture food",
    totals: MacroTotals(calories: 200, protein: 10, carbs: 25, fat: 6),
    basisDescription: "100 g", basisGrams: 100, sourceLabel: "Fixture source 1",
    sourceURL: URL(string: "https://example.invalid/food/1")!,
    attribution: "Fictional test data", sourceNote: "Fixture only")
}

@MainActor @Test func referencedFoodLoggingScalesOnceAndPreservesEditablePersonalValues() throws {
  let container = try ModelContainer(
    for: FoodItem.self, DiaryEntry.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true))
  let context = ModelContext(container)
  context.autosaveEnabled = false
  let reference = referenceFixture()
  let entry = try ReferenceFoodLogger.log(
    reference: reference, grams: 150.25, date: Date(timeIntervalSince1970: 1_700_000_000),
    meal: .lunch, in: context)
  #expect(entry.calories == 200 * 1.5025)
  #expect(entry.protein == 10 * 1.5025)
  #expect(entry.quantity == 1)
  let override = MacroTotals(calories: 250.5, protein: 21.25, carbs: 30.5, fat: 5.125)
  let changed = try ReferenceFoodLogger.log(
    reference: reference, grams: 150.25, quantity: 2, override: override,
    saveToLibrary: true, date: entry.date, meal: .dinner, in: context)
  #expect(changed.calories == 501 && changed.protein == 42.5)
  #expect(changed.foodItem?.isSavedToLibrary == true)
  #expect(changed.foodItem?.servingDescription.contains("personal values") == true)
  #expect(reference.totals.calories == 200)
  #expect(entry.calories == 200 * 1.5025)
  #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).count == 2)
}

@MainActor @Test(arguments: [0.0, -1.0, Double.infinity, Double.nan])
func referencePortionRejectsInvalidWeightsAndQuantities(value: Double) throws {
  #expect(throws: (any Error).self) { try referenceFixture().portionTotals(grams: value) }
  let container = try ModelContainer(
    for: FoodItem.self, DiaryEntry.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true))
  let context = ModelContext(container)
  #expect(throws: (any Error).self) {
    try ReferenceFoodLogger.log(
      reference: referenceFixture(), grams: 100, quantity: value, date: .now, meal: .snack,
      in: context)
  }
  #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).isEmpty)
  #expect(try context.fetch(FetchDescriptor<FoodItem>()).isEmpty)
}

@MainActor @Test func failedReferenceLogKeepsUnrelatedPendingDraft() throws {
  enum SaveFailure: Error { case diskFull }
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  let container = try ModelContainer(for: FoodItem.self, DiaryEntry.self, configurations: config)
  let context = ModelContext(container)
  context.autosaveEnabled = false
  let draft = FoodItem(
    name: "Unrelated draft", calories: 4, proteinGrams: 1, carbGrams: 0, fatGrams: 0,
    servingDescription: "Draft")
  context.insert(draft)
  #expect(throws: (any Error).self) {
    try ReferenceFoodLogger.log(
      reference: referenceFixture(), grams: 100, date: .now, meal: .snack, in: context,
      persist: { _ in throw SaveFailure.diskFull })
  }
  #expect(context.hasChanges && draft.name == "Unrelated draft")
  #expect(try context.fetch(FetchDescriptor<FoodItem>()).map(\.id) == [draft.id])
  #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).isEmpty)
}

@MainActor @Test func liquidReferencesNeverUseAnAssumedDensity() throws {
  let liquid = FoodNutritionReference(
    id: "liquid:1", name: "Fixture drink",
    totals: MacroTotals(calories: 40, protein: 1, carbs: 8, fat: 0),
    basisDescription: "100 ml", basisGrams: nil, sourceLabel: "Fixture",
    sourceURL: URL(string: "https://example.invalid/1")!, attribution: "Fixture", sourceNote: "")
  #expect(try liquid.portionTotals(grams: nil).calories == 40)
  #expect(throws: (any Error).self) { try liquid.portionTotals(grams: 100) }
}

@MainActor @Test func personalRestaurantNamesAreUniqueAndSearchMatchesAllWords() throws {
  let container = try ModelContainer(
    for: Restaurant.self, MenuItem.self, BuildableItemTemplate.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true))
  let context = ModelContext(container)
  let created = try CustomRestaurantEditor.create(name: "  Café Local  ", in: context)
  #expect(created.name == "Café Local" && created.menuItems.isEmpty)
  #expect(throws: RestaurantInputError.duplicateName) {
    try CustomRestaurantEditor.create(name: "CAFE-LOCAL", in: context)
  }
  for name in ["", "  ", "!!!", String(repeating: "A", count: 101)] {
    #expect(throws: RestaurantInputError.invalidName) {
      try CustomRestaurantEditor.create(name: name, in: context)
    }
  }
  #expect(try context.fetch(FetchDescriptor<Restaurant>()).count == 1)
  #expect(FoodSearchText.matches("LongHorn Steakhouse · Steak Side", query: "side longhorn"))
  #expect(!FoodSearchText.matches("LongHorn Steakhouse · Steak Side", query: "side pasta"))
  #expect(RestaurantSourceDirectory.nutritionURL(for: "Chick-fil-A")?.host == "www.chick-fil-a.com")
  #expect(RestaurantSourceDirectory.nutritionURL(for: "Café Local") == nil)
}
