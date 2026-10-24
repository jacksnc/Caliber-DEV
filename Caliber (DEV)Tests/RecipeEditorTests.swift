import Foundation
import SwiftData
import Testing

@testable import Caliber__DEV_

@MainActor
private func makeRecipeStore() throws -> (ModelContainer, ModelContext) {
  let container = try ModelContainer(
    for: SavedMeal.self, SavedMealItem.self, FoodItem.self, DiaryEntry.self, Restaurant.self,
    MenuItem.self, BuildableItemTemplate.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true))
  let context = ModelContext(container)
  context.autosaveEnabled = false
  return (container, context)
}

@MainActor
private func goldenRecipeDrafts() -> [RecipeIngredientDraft] {
  [
    RecipeIngredientDraft(
      name: "First ingredient", servingDescription: "100 g · source A",
      totals: MacroTotals(calories: 100, protein: 10, carbs: 5, fat: 2), quantity: 2),
    RecipeIngredientDraft(
      name: "Second ingredient", servingDescription: "1 piece · source B",
      totals: MacroTotals(calories: 50, protein: 1, carbs: 10, fat: 0.5), quantity: 3),
  ]
}

@MainActor @Test func recipeSaveSnapshotsIngredientsAndLogsSelectedCookedWeight() throws {
  let (container, context) = try makeRecipeStore()
  let drafts = goldenRecipeDrafts()
  let meal = try RecipeEditor.save(
    name: "My Batch", ingredients: drafts, servings: 4, cookedYieldGrams: 500,
    rawBatchGrams: 600, in: context)
  #expect(meal.items.count == 2)
  let batch = try RecipeEditor.batch(for: meal)
  #expect(batch.totals.calories == 350 && batch.servings == 4)
  #expect(batch.rawToCookedFactor == 5.0 / 6.0)
  let entries = try RecipeLogger.log(
    meal: meal, amount: 125, unit: .cookedGrams, date: .now, mealType: .lunch, in: context)
  #expect(entries.count == 2)
  #expect(abs(entries.reduce(0) { $0 + $1.calories } - 87.5) < 0.000_000_1)
  #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).count == 2)
  // Editing a diary copy cannot alter the saved recipe ingredient.
  entries[0].foodItem?.calories = 9_999
  #expect(try RecipeEditor.batch(for: meal).totals.calories == 350)
  try context.save()
  let reloaded = try #require(ModelContext(container).fetch(FetchDescriptor<SavedMeal>()).first)
  #expect(reloaded.id == meal.id && reloaded.items.count == 2)
  #expect(
    reloaded.items.compactMap(\.foodItem?.name).sorted()
      == ["First ingredient", "Second ingredient"])
}

@MainActor @Test func recipeMealOverrideLogsOneEditableEntryWithoutChangingIngredients() throws {
  let (_, context) = try makeRecipeStore()
  let meal = try RecipeEditor.save(
    name: "Edited Meal", ingredients: goldenRecipeDrafts(), servings: 4,
    cookedYieldGrams: 500, rawBatchGrams: nil, in: context)
  let original = meal.items.map { $0.foodItem?.calories }
  let entries = try RecipeLogger.log(
    meal: meal, amount: 0.5, unit: .servings,
    override: MacroTotals(calories: 99.5, protein: 7.25, carbs: 4.5, fat: 2.125),
    date: .now, mealType: .breakfast, in: context)
  #expect(entries.count == 1 && entries[0].calories == 99.5)
  #expect(entries[0].foodItem?.servingDescription.contains("personal values") == true)
  #expect(meal.items.map { $0.foodItem?.calories } == original)
}

@MainActor @Test func failedRecipeEditRestoresOnlyItsPriorMealAndKeepsOtherDrafts() throws {
  enum Failure: Error { case diskFull }
  let (_, context) = try makeRecipeStore()
  let meal = try RecipeEditor.save(
    name: "Existing", ingredients: goldenRecipeDrafts(), servings: 4,
    cookedYieldGrams: 500, rawBatchGrams: 600, in: context)
  let originalItems = meal.items
  let originalFoods = meal.items.compactMap(\.foodItem)
  let originalTotals = try RecipeEditor.batch(for: meal).totals
  let unrelated = FoodItem(
    name: "Unrelated pending draft", calories: 1, proteinGrams: 1, carbGrams: 1, fatGrams: 1,
    servingDescription: "Draft")
  context.insert(unrelated)
  #expect(throws: (any Error).self) {
    try RecipeEditor.save(
      meal: meal, name: "Changed", ingredients: [goldenRecipeDrafts()[0]], servings: 2,
      cookedYieldGrams: nil, rawBatchGrams: nil, in: context,
      persist: { _ in throw Failure.diskFull })
  }
  #expect(meal.name == "Existing" && meal.servings == 4 && meal.cookedYieldGrams == 500)
  #expect(meal.items.map(\.id).sorted() == originalItems.map(\.id).sorted())
  #expect(meal.items.compactMap(\.foodItem).map(\.id).sorted() == originalFoods.map(\.id).sorted())
  #expect(try RecipeEditor.batch(for: meal).totals == originalTotals)
  #expect(context.hasChanges && unrelated.name == "Unrelated pending draft")
  #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).isEmpty)
  try context.save()
  #expect(try context.fetch(FetchDescriptor<SavedMeal>()).map(\.id) == [meal.id])
  try RecipeEditor.save(
    meal: meal, name: "Retry edit", ingredients: goldenRecipeDrafts(), servings: 3,
    cookedYieldGrams: nil, rawBatchGrams: nil, in: context)
  #expect(try context.fetch(FetchDescriptor<SavedMeal>()).map(\.name) == ["Retry edit"])
  #expect(try context.fetch(FetchDescriptor<SavedMealItem>()).count == originalItems.count)
}

@MainActor @Test func failedRecipeLogLeavesNoPartialDiaryRowsOrFoodCopies() throws {
  enum Failure: Error { case diskFull }
  let (_, context) = try makeRecipeStore()
  let meal = try RecipeEditor.save(
    name: "Dinner", ingredients: goldenRecipeDrafts(), servings: 4,
    cookedYieldGrams: 500, rawBatchGrams: nil, in: context)
  let draft = FoodItem(
    name: "Another draft", calories: 1, proteinGrams: 0, carbGrams: 0, fatGrams: 0,
    servingDescription: "Pending")
  context.insert(draft)
  #expect(throws: (any Error).self) {
    try RecipeLogger.log(
      meal: meal, amount: 1, unit: .servings, date: .now, mealType: .dinner,
      in: context, persist: { _ in throw Failure.diskFull })
  }
  #expect(context.hasChanges && draft.name == "Another draft")
  #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).isEmpty)
  #expect(try context.fetch(FetchDescriptor<FoodItem>()).count == meal.items.count + 1)
}

@MainActor @Test func failedRecipeDeleteCanRetryWithoutDeletingDiaryOrFoodLibrary() throws {
  enum Failure: Error { case diskFull }
  let (_, context) = try makeRecipeStore()
  let savedFood = FoodItem(
    name: "Favorite source", calories: 10, proteinGrams: 1, carbGrams: 2, fatGrams: 1,
    servingDescription: "Source", isSavedToLibrary: true)
  context.insert(savedFood)
  let meal = try RecipeEditor.save(
    name: "Breakfast",
    ingredients: [
      RecipeIngredientDraft(
        name: "Favorite source", servingDescription: "Source",
        totals: MacroTotals(calories: 10, protein: 1, carbs: 2, fat: 1), sourceType: .generic)
    ], servings: 1, cookedYieldGrams: nil, rawBatchGrams: nil, in: context)
  let entry = DiaryEntry(date: .now, mealType: .breakfast, foodItem: savedFood)
  context.insert(entry)
  try context.save()
  #expect(throws: (any Error).self) {
    try RecipeEditor.delete(meal: meal, in: context, persist: { _ in throw Failure.diskFull })
  }
  #expect(meal.items.count == 1 && meal.items[0].foodItem != nil)
  try context.save()
  #expect(try context.fetch(FetchDescriptor<SavedMeal>()).count == 1)
  #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).count == 1)
  #expect(try context.fetch(FetchDescriptor<FoodItem>()).contains { $0.isSavedToLibrary })
  try RecipeEditor.delete(meal: meal, in: context)
  #expect(try context.fetch(FetchDescriptor<SavedMeal>()).isEmpty)
  #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).count == 1)
  #expect(try context.fetch(FetchDescriptor<FoodItem>()).map(\.name) == ["Favorite source"])
}

@MainActor @Test func recipeEditorRejectsMissingOrUnweighedPortionBeforeAnyWrite() throws {
  let (_, context) = try makeRecipeStore()
  let water = RecipeIngredientDraft(
    name: "Water", servingDescription: "1 cup", totals: MacroTotals(), quantity: 1)
  let meal = try RecipeEditor.save(
    name: "Measured only by servings", ingredients: [water], servings: 2,
    cookedYieldGrams: nil, rawBatchGrams: nil, in: context)
  #expect(throws: RecipeBatchNutritionError.missingCookedYield) {
    try RecipeLogger.log(
      meal: meal, amount: 120, unit: .cookedGrams, date: .now, mealType: .snack, in: context)
  }
  #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).isEmpty)
  #expect(throws: RecipeEditor.InputError.missingFood) {
    let meal = SavedMeal(name: "Broken")
    meal.items = [
      SavedMealItem(
        foodItem: FoodItem(
          name: "Transient", calories: 1, proteinGrams: 1, carbGrams: 1, fatGrams: 1,
          servingDescription: "1 serving"))
    ]
    meal.items[0].foodItem = nil
    try _ = RecipeEditor.batch(for: meal)
  }
}
