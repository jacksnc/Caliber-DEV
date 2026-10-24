import CaliberDatabase
import Foundation
import SwiftData
import Testing

@testable import Caliber__DEV_

@MainActor
private func recipePersistenceFixture() throws -> (ModelContainer, ModelContext, SavedMeal) {
  let schema = LegacyRestoreRehearsal.schema
  let container = try ModelContainer(
    for: schema,
    configurations: [
      ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    ])
  let context = ModelContext(container)
  context.autosaveEnabled = false
  let food = FoodItem(
    name: "Original ingredient snapshot", calories: 350.125,
    proteinGrams: 30.25, carbGrams: 40.5, fatGrams: 11.125,
    servingDescription: "Original entered portion", isSavedToLibrary: true)
  let meal = SavedMeal(name: "Original saved meal")
  let item = SavedMealItem(foodItem: food, quantity: 1.25)
  let diary = DiaryEntry(
    date: Date(timeIntervalSince1970: 1_700_000_000.125),
    mealType: .dinner, foodItem: food, quantity: 1.5, note: "Keep original diary note")
  for model in [food as any PersistentModel, meal, item, diary] { context.insert(model) }
  meal.items = [item]
  item.savedMeal = meal
  try context.save()
  return (container, context, meal)
}

private func recipePersistenceChange(
  _ rows: [LegacySnapshotRow], _ values: [String: Any], remove: String? = nil
) throws -> [LegacySnapshotRow] {
  var result = rows
  let index = try #require(result.firstIndex { $0.entity == "SavedMeal" })
  let row = result[index]
  var fields = try #require(JSONSerialization.jsonObject(with: row.payload) as? [String: Any])
  fields.merge(values) { _, value in value }
  if let remove { fields.removeValue(forKey: remove) }
  result[index] = LegacySnapshotRow(
    entity: row.entity, id: row.id,
    payload: try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]),
    references: row.references)
  return result
}

@MainActor @Test func recipeDefaultsKeepTheExactLegacySavedMealPayload() throws {
  let (_, context, meal) = try recipePersistenceFixture()
  #expect(meal.servings == 1 && meal.cookedYieldGrams == nil && meal.rawBatchGrams == nil)
  let rows = try LegacySnapshotAdapter.capture(context)
  let row = try #require(rows.first { $0.entity == "SavedMeal" })
  let legacyBytes = try JSONSerialization.data(
    withJSONObject: [
      "name": meal.name, "items": meal.items.map { $0.id.uuidString }.sorted(),
    ], options: [.sortedKeys])
  #expect(row.payload == legacyBytes)
  #expect(try LegacyRestoreRehearsal.verify(rows).restoredRows == rows)
  #expect(try LegacySnapshotAdapter.capture(context) == rows)
}

@MainActor
@Test(arguments: ["servings only", "cooked only", "raw only", "all measured"])
func recipeMetadataSurvivesArchiveRestoreAndIndependentRead(_ variant: String) async throws {
  let (container, context, meal) = try recipePersistenceFixture()
  let original = try LegacySnapshotAdapter.capture(context)
  switch variant {
  case "servings only": meal.servings = 2.5
  case "cooked only": meal.cookedYieldGrams = 450.125
  case "raw only": meal.rawBatchGrams = 550.25
  default:
    meal.servings = 2.5
    meal.cookedYieldGrams = 450.125
    meal.rawBatchGrams = 550.25
  }
  try context.save()
  let rows = try LegacySnapshotAdapter.capture(context)
  let saved = try #require(rows.first { $0.entity == "SavedMeal" })
  let fields = try #require(JSONSerialization.jsonObject(with: saved.payload) as? [String: Any])
  #expect(
    Set(fields.keys) == [
      "name", "items", "payloadVersion", "servings", "cookedYieldGrams", "rawBatchGrams",
    ])
  #expect((fields["payloadVersion"] as? NSNumber)?.intValue == 2)
  #expect(rows.filter { $0.entity != "SavedMeal" } == original.filter { $0.entity != "SavedMeal" })
  let reloaded = try #require(ModelContext(container).fetch(FetchDescriptor<SavedMeal>()).first)
  #expect(reloaded.id == meal.id && reloaded.servings == meal.servings)
  #expect(
    reloaded.cookedYieldGrams == meal.cookedYieldGrams
      && reloaded.rawBatchGrams == meal.rawBatchGrams)
  #expect(try LegacyRestoreRehearsal.verify(rows).restoredRows == rows)
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "RecipeArchiveTests-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let archive = try LegacyShadowArchive(directory: directory)
  let oldSnapshot = try await archive.copy(original)
  let newSnapshot = try await archive.copy(rows)
  let reopened = try LegacyShadowArchive(directory: directory)
  #expect(try await reopened.read(snapshotID: oldSnapshot) == original)
  #expect(try await reopened.read(snapshotID: newSnapshot) == rows)
  #expect(
    try LegacyRestoreRehearsal.verify(await reopened.read(snapshotID: newSnapshot)).restoredRows
      == rows)
  #expect(try LegacySnapshotAdapter.capture(context) == rows)
  meal.servings = 1
  meal.cookedYieldGrams = nil
  meal.rawBatchGrams = nil
  try context.save()
  #expect(try LegacySnapshotAdapter.capture(context) == original)
  #expect(try await reopened.read(snapshotID: newSnapshot) == rows)
}

@MainActor
@Test(arguments: [
  "partial extension", "missing cooked key", "missing raw key", "wrong version",
  "boolean version", "boolean servings", "zero servings", "negative cooked", "zero raw",
  "string raw", "unknown field", "noncanonical defaults",
])
func recipeRestoreRejectsInvalidMetadataWithoutChangingSource(_ kind: String) throws {
  let (_, context, meal) = try recipePersistenceFixture()
  meal.servings = 2.5
  meal.cookedYieldGrams = 450.125
  meal.rawBatchGrams = 550.25
  try context.save()
  let rows = try LegacySnapshotAdapter.capture(context)
  let invalid: [LegacySnapshotRow]
  switch kind {
  case "partial extension":
    invalid = try recipePersistenceChange(rows, [:], remove: "payloadVersion")
  case "missing cooked key":
    invalid = try recipePersistenceChange(rows, [:], remove: "cookedYieldGrams")
  case "missing raw key": invalid = try recipePersistenceChange(rows, [:], remove: "rawBatchGrams")
  case "wrong version": invalid = try recipePersistenceChange(rows, ["payloadVersion": 3])
  case "boolean version": invalid = try recipePersistenceChange(rows, ["payloadVersion": true])
  case "boolean servings": invalid = try recipePersistenceChange(rows, ["servings": true])
  case "zero servings": invalid = try recipePersistenceChange(rows, ["servings": 0])
  case "negative cooked": invalid = try recipePersistenceChange(rows, ["cookedYieldGrams": -1])
  case "zero raw": invalid = try recipePersistenceChange(rows, ["rawBatchGrams": 0])
  case "string raw": invalid = try recipePersistenceChange(rows, ["rawBatchGrams": "550.25"])
  case "unknown field": invalid = try recipePersistenceChange(rows, ["inferredDensity": 1])
  default:
    invalid = try recipePersistenceChange(
      rows, ["servings": 1, "cookedYieldGrams": NSNull(), "rawBatchGrams": NSNull()])
  }
  #expect(throws: FoundationStorageError.invalidFixture) {
    try LegacyRestoreRehearsal.verify(invalid)
  }
  #expect(try LegacySnapshotAdapter.capture(context) == rows)
  #expect(meal.servings == 2.5 && meal.cookedYieldGrams == 450.125 && meal.rawBatchGrams == 550.25)
}

@MainActor @Test func recipeRestoreFailureKeepsOriginalSnapshotAndCanRetry() throws {
  let (_, context, meal) = try recipePersistenceFixture()
  meal.servings = 2.5
  meal.rawBatchGrams = 550.25
  try context.save()
  let rows = try LegacySnapshotAdapter.capture(context)
  for stage in [0, 2, rows.count - 1] {
    #expect(throws: FoundationStorageError.unavailable) {
      try LegacyRestoreRehearsal.verify(rows, failAfter: stage)
    }
    #expect(try LegacySnapshotAdapter.capture(context) == rows)
  }
  #expect(try LegacyRestoreRehearsal.verify(rows).restoredRows == rows)
}
