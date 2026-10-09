import CaliberDatabase
import Foundation
import SwiftData
import Testing

@testable import Caliber__DEV_

@MainActor @Test func legacyShadowCopyPreservesPhotosRelationshipsAndOriginalUnits() async throws {
  let schema = Schema([
    FoodItem.self, Restaurant.self, MenuItem.self, MenuItemModifier.self,
    BuildableItemTemplate.self, BuildComponentCategory.self, BuildComponentOption.self,
    SavedMeal.self, SavedMealItem.self, DiaryEntry.self, WeightEntry.self, ProgressEntry.self,
    ProgressPhoto.self, Note.self, UserProfile.self,
  ])
  let container = try ModelContainer(
    for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
  let context = ModelContext(container)
  context.autosaveEnabled = false
  try await RestaurantCatalogSeeder.seedIfNeeded(in: context)
  let food = FoodItem(
    name: "Copy fixture", calories: 123.5, proteinGrams: 8, carbGrams: 15, fatGrams: 3.5,
    servingDescription: "Fixture portion")
  context.insert(food)
  let entry = DiaryEntry(
    date: Date(timeIntervalSince1970: 1_700_000_000), mealType: .lunch, foodItem: food,
    quantity: 1.5)
  context.insert(entry)
  context.insert(Note(date: entry.date, text: "Fixture note", linkedDiaryEntry: entry))
  let meal = SavedMeal(name: "Fixture meal")
  let item = SavedMealItem(foodItem: food, quantity: 2)
  context.insert(meal)
  context.insert(item)
  meal.items = [item]
  item.savedMeal = meal
  context.insert(
    UserProfile(
      heightInInches: 70, startingWeight: 180, activityLevel: .sedentary, dailyCalorieGoal: 2200,
      proteinGoal: 160, carbGoal: 230, fatGoal: 70))
  try context.save()
  let checkIn = try ProgressEntryEditor.save(
    date: entry.date, weightInPounds: 180.125, notes: "Original text",
    photos: [ProgressPhotoDraft(imageData: Data([1, 2, 3, 4]))], in: context)
  let before = try LegacySnapshotAdapter.capture(context)
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "LegacyCopy-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let archive = try LegacyShadowArchive(directory: directory)
  let id = try await archive.copy(before)
  let reopened = try LegacyShadowArchive(directory: directory)
  #expect(try await reopened.read(snapshotID: id) == before)
  #expect(try LegacySnapshotAdapter.capture(context) == before)
  #expect(checkIn.weightEntry?.weightInPounds == 180.125)
  let photo = try #require(before.first { $0.entity == "ProgressPhoto" })
  let payload = try #require(JSONSerialization.jsonObject(with: photo.payload) as? [String: Any])
  #expect(payload["imageDataBase64"] as? String == Data([1, 2, 3, 4]).base64EncodedString())
  let mapped = try await reopened.mappedID(entity: "FoodItem", legacyID: food.id.uuidString)
  _ = try await reopened.copy(before)
  #expect(try await reopened.mappedID(entity: "FoodItem", legacyID: food.id.uuidString) == mapped)
  await #expect(throws: FoundationStorageError.unavailable) {
    try await reopened.copy(before, failAfter: 2)
  }
  #expect(try await reopened.snapshotCount() == 2)
  #expect(try LegacySnapshotAdapter.capture(context) == before)
  #expect(Set(before.map(\.entity)).count == 15)
}
