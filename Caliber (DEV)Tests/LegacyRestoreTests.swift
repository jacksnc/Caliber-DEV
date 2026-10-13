import CaliberDatabase
import Foundation
import SwiftData
import Testing

@testable import Caliber__DEV_

@MainActor
private func restoreFixture() throws -> (ModelContext, [LegacySnapshotRow]) {
  let container = try ModelContainer(
    for: LegacyRestoreRehearsal.schema,
    configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
  let context = ModelContext(container)
  context.autosaveEnabled = false
  let restaurant = Restaurant(name: "Fictional local restaurant")
  let menu = MenuItem(
    name: "Owner's custom meal", baseCalories: 501.125, baseProtein: 32.25,
    baseCarbs: 44.5, baseFat: 17.25, category: .entree, isCustom: true)
  let food = FoodItem(
    name: "Adjusted logged meal", calories: 425.125, proteinGrams: 30.5,
    carbGrams: 40.25, fatGrams: 15.125, servingDescription: "Custom portion",
    sourceType: .restaurantMenuItem, isSavedToLibrary: true, menuItem: menu)
  let diary = DiaryEntry(
    date: Date(timeIntervalSince1970: 1_700_000_000.125),
    mealType: .dinner, foodItem: food, quantity: 1.25, note: "Original diary text")
  let weight = WeightEntry(date: diary.date, weightInPounds: 180.125)
  let standaloneWeight = WeightEntry(
    date: diary.date.addingTimeInterval(-86_400), weightInPounds: 181.75)
  let progress = ProgressEntry(
    date: diary.date, notes: "Original progress text", weightEntry: weight)
  let first = ProgressPhoto(imageData: Data([1, 2, 3]), sortOrder: 1)
  let large = ProgressPhoto(
    imageData: Data((0..<196_608).map { UInt8($0 % 251) }), sortOrder: 0)
  // Tie order uses preserved UUIDs, not SwiftData's relationship array order.
  let tied = ProgressPhoto(imageData: Data([7, 8, 9]), sortOrder: 1)
  for model in [
    restaurant as any PersistentModel, menu, food, diary, weight, standaloneWeight,
    progress, first, large, tied,
  ] { context.insert(model) }
  menu.restaurant = restaurant
  restaurant.menuItems = [menu]
  weight.progressEntry = progress
  progress.photos = [first, tied, large]
  for photo in progress.photos { photo.progressEntry = progress }
  try context.save()
  return (context, try LegacySnapshotAdapter.capture(context))
}

private func restoreWorkspace() throws -> URL {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "CaliberRestoreTests-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  return directory
}

private func changing(
  _ rows: [LegacySnapshotRow], entity: String, field: String, value: Any
) throws -> [LegacySnapshotRow] {
  guard let index = rows.firstIndex(where: { $0.entity == entity }) else {
    throw FoundationStorageError.invalidFixture
  }
  let row = rows[index]
  var fields = try #require(JSONSerialization.jsonObject(with: row.payload) as? [String: Any])
  fields[field] = value
  var result = rows
  result[index] = LegacySnapshotRow(
    entity: row.entity, id: row.id,
    payload: try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]),
    references: row.references)
  return result
}

@MainActor @Test
func restorePreservesPhotosCustomNutritionAndStandaloneWeightWithoutChangingSource() throws {
  let (source, rows) = try restoreFixture()
  let first = try LegacyRestoreRehearsal.verify(rows)
  let second = try LegacyRestoreRehearsal.verify(rows)
  #expect(first.rehearsalID != second.rehearsalID)
  #expect(first.rowCount == 10 && first.entityCounts["ProgressPhoto"] == 3)
  #expect(first.restoredRows == rows && second.restoredRows == rows)
  #expect(try LegacySnapshotAdapter.capture(source) == rows)
  func values(_ entity: String) throws -> [String: Any] {
    let row = try #require(first.restoredRows.first { $0.entity == entity })
    return try #require(JSONSerialization.jsonObject(with: row.payload) as? [String: Any])
  }
  let diary = try values("DiaryEntry")
  let food = try values("FoodItem")
  let menu = try values("MenuItem")
  #expect(food["calories"] as? Double == 425.125)
  #expect(menu["calories"] as? Double == 501.125)
  #expect(menu["isCustom"] as? Bool == true)
  #expect(diary["caloriesSnapshot"] as? Double == 425.125 * 1.25)
  #expect(diary["note"] as? String == "Original diary text")
  #expect(first.entityCounts["WeightEntry"] == 2)
  let photos = try first.restoredRows.filter { $0.entity == "ProgressPhoto" }.map {
    try #require(JSONSerialization.jsonObject(with: $0.payload) as? [String: Any])
  }
  #expect(
    photos.contains { photo in
      guard let encoded = photo["imageDataBase64"] as? String else { return false }
      return Data(base64Encoded: encoded)?.count == 196_608
    })
}

@MainActor @Test func failedRestoreLeavesSourceAndUnrelatedFilesIntactAndRetryWorks() throws {
  let (source, rows) = try restoreFixture()
  let workspace = try restoreWorkspace()
  defer { try? FileManager.default.removeItem(at: workspace) }
  let sentinel = workspace.appendingPathComponent("unrelated.txt")
  try Data("keep".utf8).write(to: sentinel)
  let kept = try LegacyRestoreRehearsal.verify(rows)
  #expect(throws: FoundationStorageError.unavailable) {
    try LegacyRestoreRehearsal.verify(rows, failAfter: 2)
  }
  #expect(try FileManager.default.contentsOfDirectory(atPath: workspace.path).count == 1)
  #expect(try Data(contentsOf: sentinel) == Data("keep".utf8))
  #expect(kept.restoredRows == rows)
  #expect(try LegacySnapshotAdapter.capture(source) == rows)
  let retry = try LegacyRestoreRehearsal.verify(rows)
  #expect(retry.restoredRows == rows)
}

@MainActor @Test(arguments: [Int.min, Int.max])
func restorePreservesIntegerRanksWithoutPassingThroughDouble(order: Int) throws {
  let (source, _) = try restoreFixture()
  let photo = try #require(source.fetch(FetchDescriptor<ProgressPhoto>()).first)
  photo.sortOrder = order
  try source.save()
  let rows = try LegacySnapshotAdapter.capture(source)
  #expect(try LegacyRestoreRehearsal.verify(rows).restoredRows == rows)
  #expect(try LegacySnapshotAdapter.capture(source) == rows)
}

@MainActor
@Test(arguments: [
  "boolean nutrition", "string nutrition", "number instead of boolean", "fractional sort",
  "bad image", "wrong unit", "wrong kg", "unknown enum", "unknown field", "missing reference",
  "duplicate row", "unknown entity", "mismatched totals",
])
func invalidRestoresNeverTouchSourceOrCreateFiles(kind: String) throws {
  let (source, rows) = try restoreFixture()
  let workspace = try restoreWorkspace()
  defer { try? FileManager.default.removeItem(at: workspace) }
  let invalid: [LegacySnapshotRow]
  switch kind {
  case "boolean nutrition":
    invalid = try changing(rows, entity: "FoodItem", field: "calories", value: true)
  case "string nutrition":
    invalid = try changing(rows, entity: "FoodItem", field: "protein", value: "30.5")
  case "number instead of boolean":
    invalid = try changing(rows, entity: "MenuItem", field: "isCustom", value: 1)
  case "fractional sort":
    invalid = try changing(rows, entity: "ProgressPhoto", field: "sortOrder", value: 0.5)
  case "bad image":
    invalid = try changing(
      rows, entity: "ProgressPhoto", field: "imageDataBase64", value: "not base64!")
  case "wrong unit":
    invalid = try changing(rows, entity: "WeightEntry", field: "enteredUnit", value: "kg")
  case "wrong kg": invalid = try changing(rows, entity: "WeightEntry", field: "weightKG", value: 1)
  case "unknown enum":
    invalid = try changing(rows, entity: "FoodItem", field: "sourceType", value: "unknown")
  case "unknown field":
    invalid = try changing(rows, entity: "FoodItem", field: "futureField", value: "no silent loss")
  case "mismatched totals":
    invalid = try changing(rows, entity: "DiaryEntry", field: "caloriesSnapshot", value: 1)
  case "duplicate row": invalid = rows + [rows[0]]
  case "unknown entity":
    invalid =
      rows + [
        LegacySnapshotRow(
          entity: "Unknown", id: UUID().uuidString, payload: Data("{}".utf8), references: [])
      ]
  default:
    invalid = try changing(rows, entity: "FoodItem", field: "menuItem", value: UUID().uuidString)
  }
  #expect(throws: (any Error).self) { try LegacyRestoreRehearsal.verify(invalid) }
  #expect(try FileManager.default.contentsOfDirectory(atPath: workspace.path).isEmpty)
  #expect(try LegacySnapshotAdapter.capture(source) == rows)
}

@MainActor @Test func orphanedOptionalLinksAndEmptySnapshotRestoreWithoutInventedRecords() throws {
  let container = try ModelContainer(
    for: LegacyRestoreRehearsal.schema,
    configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
  let source = ModelContext(container)
  source.autosaveEnabled = false
  let transientFood = FoodItem(
    name: "Unused", calories: 1, proteinGrams: 0, carbGrams: 0, fatGrams: 0, servingDescription: "")
  let diary = DiaryEntry(date: .now, mealType: .snack, foodItem: transientFood, quantity: 2)
  diary.foodItem = nil
  let mealItem = SavedMealItem(foodItem: transientFood)
  mealItem.foodItem = nil
  source.insert(diary)
  source.insert(mealItem)
  try source.save()
  let rows = try LegacySnapshotAdapter.capture(source)
  #expect(rows.count == 2)
  let workspace = try restoreWorkspace()
  defer { try? FileManager.default.removeItem(at: workspace) }
  let report = try LegacyRestoreRehearsal.verify(rows)
  #expect(report.restoredRows == rows)
  let empty = try LegacyRestoreRehearsal.verify([])
  #expect(empty.rowCount == 0 && empty.entityCounts.isEmpty)
  #expect(empty.restoredRows.isEmpty)
}

@MainActor @Test func inconsistentInverseLinksCannotSilentlyRepairARehearsal() throws {
  let (source, rows) = try restoreFixture()
  let workspace = try restoreWorkspace()
  defer { try? FileManager.default.removeItem(at: workspace) }
  let edited = try changing(rows, entity: "ProgressEntry", field: "photos", value: [String]())
  let invalid = edited.map { row in
    LegacySnapshotRow(
      entity: row.entity, id: row.id, payload: row.payload,
      references: row.entity == "ProgressEntry"
        ? row.references.filter { $0.entity != "ProgressPhoto" } : row.references)
  }
  #expect(throws: FoundationStorageError.incompleteFixture) {
    try LegacyRestoreRehearsal.verify(invalid)
  }
  #expect(try FileManager.default.contentsOfDirectory(atPath: workspace.path).isEmpty)
  #expect(try LegacySnapshotAdapter.capture(source) == rows)
}
