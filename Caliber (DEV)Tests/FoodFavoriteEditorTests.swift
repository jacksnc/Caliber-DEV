import Foundation
import SwiftData
import Testing

@testable import Caliber__DEV_

@MainActor @Test func personalFavoriteRemainsSavedAfterItsDiaryEntryIsRemoved() throws {
  let suite = "Caliber.Favorites.Edit." + UUID().uuidString
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let preferences = FoodLibraryPreferences(defaults: defaults)
  let container = try ModelContainer(
    for: FoodItem.self, DiaryEntry.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true))
  let context = ModelContext(container)
  let food = FoodItem(
    name: "Fictional food", calories: 200.5, proteinGrams: 10, carbGrams: 20, fatGrams: 5,
    servingDescription: "1 plate")
  let entry = DiaryEntry(date: .now, mealType: .lunch, foodItem: food, quantity: 1.5)
  context.insert(food)
  context.insert(entry)
  try context.save()
  try FoodFavoriteEditor.setFavorite(true, food: food, preferences: preferences, in: context)
  #expect(food.isSavedToLibrary && entry.calories == 300.75)
  let key = FoodReuseIndex.key(for: food)
  #expect(preferences.isFavorite(key))
  context.delete(entry)
  try context.save()
  #expect(try context.fetch(FetchDescriptor<FoodItem>()).first?.isSavedToLibrary == true)
  try FoodFavoriteEditor.setFavorite(false, food: food, preferences: preferences, in: context)
  #expect(!preferences.isFavorite(key) && food.isSavedToLibrary)
  #expect(try ModelContext(container).fetch(FetchDescriptor<FoodItem>()).count == 1)
}

@MainActor @Test func failedPersonalFavoriteDoesNotChangePreferencesOrUnrelatedDrafts() throws {
  enum Failure: Error { case storage }
  let suite = "Caliber.Favorites.Failure." + UUID().uuidString
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let preferences = FoodLibraryPreferences(defaults: defaults)
  let container = try ModelContainer(
    for: FoodItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
  let context = ModelContext(container)
  context.autosaveEnabled = false
  let food = FoodItem(
    name: "Food", calories: 20, proteinGrams: 2, carbGrams: 2, fatGrams: 0,
    servingDescription: "1 portion")
  let other = FoodItem(
    name: "Original", calories: 1, proteinGrams: 0, carbGrams: 0, fatGrams: 0,
    servingDescription: "1 portion")
  context.insert(food)
  context.insert(other)
  try context.save()
  other.name = "Pending draft"
  #expect(throws: Failure.self) {
    try FoodFavoriteEditor.setFavorite(
      true, food: food, preferences: preferences, in: context,
      persist: { _ in throw Failure.storage })
  }
  #expect(!food.isSavedToLibrary && preferences.favoriteKeys.isEmpty)
  #expect(context.hasChanges && other.name == "Pending draft")
}

@MainActor @Test(arguments: ["", "   "])
func incompletePersonalFoodCannotBecomeAnInvisibleFavorite(text: String) throws {
  let suite = "Caliber.Favorites.Invalid." + UUID().uuidString
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let preferences = FoodLibraryPreferences(defaults: defaults)
  let container = try ModelContainer(
    for: FoodItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
  let context = ModelContext(container)
  let food = FoodItem(
    name: "Food", calories: 20, proteinGrams: 2, carbGrams: 2, fatGrams: 0, servingDescription: text
  )
  context.insert(food)
  #expect(throws: (any Error).self) {
    try FoodFavoriteEditor.setFavorite(true, food: food, preferences: preferences, in: context)
  }
  #expect(preferences.favoriteKeys.isEmpty && !food.isSavedToLibrary)
}
