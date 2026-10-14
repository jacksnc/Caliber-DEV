import Foundation
import GRDB
import Testing

@testable import CaliberDatabase

private let projectionReference = Date(timeIntervalSince1970: 1_800_000_000.125)
private let projectionSnapshot = "0199c300-1000-7000-8000-000000000099"
private let projectionZone = "America/New_York"

private func projectionID(_ n: Int) -> String {
  String(format: "00000000-0000-4000-8000-%012d", n)
}
private func projectionWorkspace() throws -> URL {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "CaliberProjectionTests-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  return directory
}
private func projectionDatabase(_ directory: URL) throws -> DatabaseQueue {
  try DatabaseQueue(
    path: directory.appendingPathComponent("normalized-rehearsal-v1/normalized-copy.sqlite").path)
}

/// All fifteen current model types, real links, independent diary snapshots, negative modifiers,
/// tied photo ranks, orphan rows, a large photo and integers beyond Double's exact range.
private func projectionFixture() throws -> [LegacySnapshotRow] {
  var rows: [LegacySnapshotRow] = []
  let null = NSNull()
  let date = 1_700_006_400.125 - Date.timeIntervalBetween1970AndReferenceDate
  func row(_ entity: String, _ n: Int, _ values: [String: Any], _ refs: [(String, Int)] = []) throws
  {
    rows.append(
      LegacySnapshotRow(
        entity: entity, id: projectionID(n),
        payload: try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]),
        references: refs.map { LegacyReference($0.0, projectionID($0.1)) }))
  }
  try row(
    "Restaurant", 1,
    [
      "name": "Fictional Local Grill", "menuItems": [projectionID(2)],
      "buildableTemplates": [projectionID(5)],
    ], [("MenuItem", 2), ("BuildableItemTemplate", 5)])
  try row(
    "MenuItem", 2,
    [
      "name": "Custom entree", "calories": 500.125, "protein": 32.5, "carbs": 40.25, "fat": 19.125,
      "category": "entree", "isCustom": true, "restaurant": projectionID(1),
      "modifiers": [projectionID(3)],
    ], [("Restaurant", 1), ("MenuItemModifier", 3)])
  try row(
    "MenuItemModifier", 3,
    [
      "name": "No sauce", "calorieDelta": -60.125, "proteinDelta": -0.5, "carbDelta": -4.25,
      "fatDelta": -4.5, "menuItem": projectionID(2),
    ], [("MenuItem", 2)])
  try row(
    "FoodItem", 4,
    [
      "name": "Edited serving", "calories": 440.125, "protein": 31.5, "carbs": 36.25, "fat": 14.125,
      "servingDescription": "Owner's portion", "sourceType": "restaurantMenuItem",
      "isSavedToLibrary": true, "menuItem": projectionID(2),
    ], [("MenuItem", 2)])
  try row(
    "BuildableItemTemplate", 5,
    ["name": "Build a bowl", "restaurant": projectionID(1), "categories": [projectionID(6)]],
    [("Restaurant", 1), ("BuildComponentCategory", 6)])
  try row(
    "BuildComponentCategory", 6,
    [
      "name": "Protein", "selectionType": "single", "isRequired": false,
      "sortOrder": Int64(9_007_199_254_740_993), "template": projectionID(5),
      "options": [projectionID(7)],
    ], [("BuildableItemTemplate", 5), ("BuildComponentOption", 7)])
  try row(
    "BuildComponentOption", 7,
    [
      "name": "Chicken", "calories": 180.25, "protein": 32.125, "carbs": 0.125, "fat": 7.5,
      "supportsDouble": true, "category": projectionID(6),
    ], [("BuildComponentCategory", 6)])
  try row(
    "DiaryEntry", 8,
    [
      "dateReference": date, "mealType": "dinner", "foodItem": projectionID(4), "quantity": 1.25,
      "note": "Custom logged values", "caloriesSnapshot": 550.15625, "proteinSnapshot": 39.375,
      "carbsSnapshot": 45.3125, "fatSnapshot": 17.65625,
    ], [("FoodItem", 4)])
  try row(
    "SavedMeal", 9, ["name": "Usual order", "items": [projectionID(10)]], [("SavedMealItem", 10)])
  try row(
    "SavedMealItem", 10,
    ["quantity": 2.25, "foodItem": projectionID(4), "savedMeal": projectionID(9)],
    [("FoodItem", 4), ("SavedMeal", 9)])
  try row(
    "WeightEntry", 11,
    [
      "dateReference": date, "enteredValue": 180.125, "enteredUnit": "lb",
      "weightKG": 180.125 * 0.45359237, "progressEntry": projectionID(12),
    ], [("ProgressEntry", 12)])
  try row(
    "ProgressEntry", 12,
    [
      "dateReference": date, "notes": "Kept original notes", "weightEntry": projectionID(11),
      "photos": [projectionID(13), projectionID(16)],
    ], [("WeightEntry", 11), ("ProgressPhoto", 13), ("ProgressPhoto", 16)])
  try row(
    "ProgressPhoto", 13,
    [
      "imageDataBase64": Data((0..<196_608).map { UInt8($0 % 251) }).base64EncodedString(),
      "sortOrder": Int64.max, "progressEntry": projectionID(12),
    ], [("ProgressEntry", 12)])
  try row(
    "Note", 14, ["dateReference": date, "text": "Diary note", "linkedDiaryEntry": projectionID(8)],
    [("DiaryEntry", 8)])
  try row(
    "UserProfile", 15,
    [
      "heightInInches": 70.25, "startingWeight": 185.125, "activityLevel": "moderatelyActive",
      "dailyCalorieGoal": Int64.max, "proteinGoal": 175.5, "carbGoal": 225.25, "fatGoal": 65.125,
    ])
  try row(
    "ProgressPhoto", 16,
    [
      "imageDataBase64": Data([7, 8, 9]).base64EncodedString(), "sortOrder": Int64.max,
      "progressEntry": projectionID(12),
    ], [("ProgressEntry", 12)])
  try row(
    "ProgressPhoto", 17,
    [
      "imageDataBase64": Data([99]).base64EncodedString(), "sortOrder": Int64.min,
      "progressEntry": null,
    ])
  try row("SavedMealItem", 18, ["quantity": 0.5, "foodItem": null, "savedMeal": null])
  try row(
    "BuildComponentCategory", 19,
    [
      "name": "Orphan group", "selectionType": "multiple", "isRequired": true,
      "sortOrder": Int64.min, "template": null, "options": [],
    ])
  try row(
    "DiaryEntry", 20,
    [
      "dateReference": date - 86_400, "mealType": "snack", "foodItem": null, "quantity": 0,
      "note": null, "caloriesSnapshot": 0, "proteinSnapshot": 0, "carbsSnapshot": 0,
      "fatSnapshot": 0,
    ])
  try row(
    "WeightEntry", 21,
    [
      "dateReference": date - 86_400, "enteredValue": 181.75, "enteredUnit": "lb",
      "weightKG": 181.75 * 0.45359237, "progressEntry": null,
    ])
  return rows.sorted { ($0.entity, $0.id) < ($1.entity, $1.id) }
}

private func projectionChanged(_ rows: [LegacySnapshotRow], entity: String, key: String, value: Any)
  throws -> [LegacySnapshotRow]
{
  var result = rows
  let index = try #require(result.firstIndex { $0.entity == entity })
  let row = result[index]
  var fields = try #require(JSONSerialization.jsonObject(with: row.payload) as? [String: Any])
  fields[key] = value
  result[index] = LegacySnapshotRow(
    entity: row.entity, id: row.id,
    payload: try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]),
    references: row.references)
  return result
}

@Test func normalizedProjectionCoversEveryCurrentModelAndPreservesSourceArchive() async throws {
  let workspace = try projectionWorkspace()
  defer { try? FileManager.default.removeItem(at: workspace) }
  let rows = try projectionFixture()
  #expect(Set(rows.map(\.entity)).count == 15)
  let archive = try LegacyShadowArchive(directory: workspace.appendingPathComponent("source"))
  let snapshot = try await archive.copy(rows)
  let mapper = try LegacyNormalizedProjection(directory: workspace)
  let report = try await mapper.copy(
    archive.read(snapshotID: snapshot), snapshotID: snapshot,
    timeZoneID: projectionZone, referenceDate: projectionReference)
  #expect(report.sourceRows == 21)
  #expect(report.canonicalRows == 16)
  #expect(report.compatibilityRows == 18)
  #expect(report.diaryCalories == 550.15625)
  #expect(report.diaryProtein == 39.375)
  #expect(report.diaryCarbs == 45.3125)
  #expect(report.diaryFat == 17.65625)
  #expect(report.photos == 3)
  #expect(report.photoBytes == 196_612)
  #expect(report.warnings.contains { $0.contains("gram weights are unknown") })
  #expect(report.warnings.contains { $0.contains("America/New_York") })
  #expect(try await archive.read(snapshotID: snapshot) == rows)
  #expect(try await archive.snapshotCount() == 1)
  #expect(
    try await mapper.normalizedRows()
      == rows.map {
        LegacySnapshotRow(
          entity: $0.entity, id: $0.id, payload: $0.payload,
          references: $0.references.sorted { ($0.entity, $0.id) < ($1.entity, $1.id) })
      })
  let db = try projectionDatabase(workspace)
  try await db.read { database throws -> Void in
    #expect(try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM food_logs") == 0)
    #expect(try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM food_nutrients") == 0)
    #expect(try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM sync_outbox") == 0)
    #expect(try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM foods") == 4)
    #expect(try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM meal_logs") == 2)
    #expect(try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM attachments") == 2)
    #expect(try Double.fetchOne(database, sql: "SELECT height_cm FROM accounts") == 70.25 * 2.54)
    #expect(try Int.fetchOne(database, sql: "SELECT SUM(metadata_stripped) FROM attachments") == 0)
    #expect(
      try String.fetchOne(
        database, sql: "SELECT local_date FROM meal_logs WHERE notes='Custom logged values'")
        == "2023-11-14")
    #expect(
      try Int64.fetchOne(database, sql: "SELECT position FROM food_component_groups")
        == 9_007_199_254_740_993)
    #expect(
      try Int64.fetchOne(database, sql: "SELECT calorie_goal FROM projection_profiles") == Int64.max
    )
    #expect(try String.fetchOne(database, sql: "SELECT mode FROM sync_context") == "local")
    #expect(try Row.fetchAll(database, sql: "PRAGMA foreign_key_check").isEmpty)
  }
  #expect(
    !FileManager.default.fileExists(atPath: workspace.appendingPathComponent("core.sqlite").path))
  #expect(
    !FileManager.default.fileExists(atPath: workspace.appendingPathComponent("stack.sqlite").path))
}

@Test func normalizedProjectionFailureRollsBackEveryRecordAndRetrySurvivesReopen() async throws {
  let workspace = try projectionWorkspace()
  defer { try? FileManager.default.removeItem(at: workspace) }
  let rows = try projectionFixture()
  let mapper = try LegacyNormalizedProjection(directory: workspace)
  let db = try projectionDatabase(workspace)
  for stage in [0, 1, 7, rows.count - 1] {
    await #expect(throws: FoundationStorageError.unavailable) {
      try await mapper.copy(
        rows, snapshotID: projectionSnapshot, timeZoneID: projectionZone,
        referenceDate: projectionReference, failAfter: stage)
    }
    try await db.read { d throws -> Void in
      for table in [
        "accounts", "legacy_id_map", "projection_source_rows", "projection_diary",
        "projection_photos", "projection_manifest",
      ] {
        #expect(try Int.fetchOne(d, sql: "SELECT COUNT(*) FROM \(table)") == 0)
      }
    }
  }
  let first = try await mapper.copy(
    rows, snapshotID: projectionSnapshot, timeZoneID: projectionZone,
    referenceDate: projectionReference)
  let id = try #require(await mapper.mappedID(entity: "FoodItem", legacyID: projectionID(4)))
  #expect(id[id.index(id.startIndex, offsetBy: 14)] == "7")
  let again = try await mapper.copy(
    rows.reversed(), snapshotID: projectionSnapshot,
    timeZoneID: projectionZone, referenceDate: projectionReference, failAfter: 0)
  #expect(again == first)
  let reopened = try LegacyNormalizedProjection(directory: workspace)
  #expect(try await reopened.mappedID(entity: "FoodItem", legacyID: projectionID(4)) == id)
  #expect(
    try await reopened.copy(
      rows, snapshotID: projectionSnapshot,
      timeZoneID: projectionZone, referenceDate: projectionReference) == first)
  #expect(
    try await db.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM legacy_id_map") }
      == rows.count)
}

@Test func normalizedProjectionRefusesChangedSourceOrAssumptionsWithoutChangingCopy() async throws {
  let workspace = try projectionWorkspace()
  defer { try? FileManager.default.removeItem(at: workspace) }
  let rows = try projectionFixture()
  let mapper = try LegacyNormalizedProjection(directory: workspace)
  let report = try await mapper.copy(
    rows, snapshotID: projectionSnapshot, timeZoneID: projectionZone,
    referenceDate: projectionReference)
  let changed = try projectionChanged(
    rows, entity: "FoodItem", key: "name", value: "Changed after snapshot")
  await #expect(throws: FoundationStorageError.differentFixture) {
    try await mapper.copy(
      changed, snapshotID: projectionSnapshot, timeZoneID: projectionZone,
      referenceDate: projectionReference)
  }
  await #expect(throws: FoundationStorageError.differentFixture) {
    try await mapper.copy(
      rows, snapshotID: UUID().uuidString, timeZoneID: projectionZone,
      referenceDate: projectionReference)
  }
  await #expect(throws: FoundationStorageError.differentFixture) {
    try await mapper.copy(
      rows, snapshotID: projectionSnapshot, timeZoneID: "UTC", referenceDate: projectionReference)
  }
  await #expect(throws: FoundationStorageError.differentFixture) {
    try await mapper.copy(
      rows, snapshotID: projectionSnapshot, timeZoneID: projectionZone,
      referenceDate: projectionReference.addingTimeInterval(1))
  }
  #expect(
    try await mapper.reconcile(
      rows, snapshotID: projectionSnapshot, timeZoneID: projectionZone,
      referenceDate: projectionReference) == report)
}

@Test func normalizedProjectionDetectsTypedDataAndArchiveTampering() async throws {
  for mutation in [
    "UPDATE projection_photos SET image_bytes=X'01' WHERE position<0",
    "UPDATE projection_source_rows SET payload=X'7B7D' WHERE entity='FoodItem'",
    "UPDATE projection_diary SET calories=calories+1",
    "UPDATE sync_context SET mode='remote_apply',logical_clock=logical_clock+1; UPDATE foods SET name='tampered',logical_clock=logical_clock+1",
    "UPDATE projection_links SET position=position+100 WHERE field='photos'",
  ] {
    let workspace = try projectionWorkspace()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let rows = try projectionFixture()
    let mapper = try LegacyNormalizedProjection(directory: workspace)
    _ = try await mapper.copy(
      rows, snapshotID: projectionSnapshot, timeZoneID: projectionZone,
      referenceDate: projectionReference)
    try await projectionDatabase(workspace).write { try $0.execute(sql: mutation) }
    await #expect(throws: FoundationStorageError.incompleteFixture) {
      try await mapper.reconcile(
        rows, snapshotID: projectionSnapshot, timeZoneID: projectionZone,
        referenceDate: projectionReference)
    }
    await #expect(throws: FoundationStorageError.incompleteFixture) {
      try await mapper.copy(
        rows, snapshotID: projectionSnapshot, timeZoneID: projectionZone,
        referenceDate: projectionReference)
    }
  }
}

@Test func normalizedProjectionRejectsMalformedRelationshipsValuesAndDuplicateIDsBeforeWrites()
  async throws
{
  let rows = try projectionFixture()
  var invalid = [
    try projectionChanged(rows, entity: "FoodItem", key: "calories", value: true),
    try projectionChanged(rows, entity: "WeightEntry", key: "weightKG", value: 100),
    try projectionChanged(rows, entity: "ProgressPhoto", key: "imageDataBase64", value: "%%%"),
    try projectionChanged(rows, entity: "BuildComponentCategory", key: "sortOrder", value: 1.5),
    try projectionChanged(rows, entity: "DiaryEntry", key: "dateReference", value: -2_000_000_000),
    try projectionChanged(rows, entity: "MenuItem", key: "category", value: "unknown"),
    try projectionChanged(rows, entity: "FoodItem", key: "unknownField", value: "new schema"),
    rows + [rows[0]],
  ]
  var missing = rows
  missing.removeAll { $0.entity == "FoodItem" }
  invalid.append(missing)
  // Modify the payload AND the sidecar consistently: inverse relationship validation still rejects it.
  var conflict = try projectionChanged(rows, entity: "MenuItem", key: "restaurant", value: NSNull())
  let i = try #require(conflict.firstIndex { $0.entity == "MenuItem" })
  conflict[i] = LegacySnapshotRow(
    entity: conflict[i].entity, id: conflict[i].id, payload: conflict[i].payload,
    references: conflict[i].references.filter { $0.entity != "Restaurant" })
  invalid.append(conflict)
  for candidate in invalid {
    let workspace = try projectionWorkspace()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let mapper = try LegacyNormalizedProjection(directory: workspace)
    await #expect(throws: FoundationStorageError.invalidFixture) {
      try await mapper.copy(
        candidate, snapshotID: projectionSnapshot, timeZoneID: projectionZone,
        referenceDate: projectionReference)
    }
    #expect(
      try await projectionDatabase(workspace).read {
        try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM accounts")
      } == 0)
  }
}

@Test func normalizedProjectionRefusesArbitraryExistingTargetAndRequiresTimeZone() async throws {
  let workspace = try projectionWorkspace()
  defer { try? FileManager.default.removeItem(at: workspace) }
  let target = workspace.appendingPathComponent("normalized-rehearsal-v1")
  try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
  let db = try projectionDatabase(workspace)
  try await db.write {
    try $0.execute(sql: "CREATE TABLE live_data(value TEXT); INSERT INTO live_data VALUES('keep')")
  }
  #expect(throws: FoundationStorageError.differentFixture) {
    try LegacyNormalizedProjection(directory: workspace)
  }
  #expect(
    try await db.read { try String.fetchOne($0, sql: "SELECT value FROM live_data") } == "keep")
  let other = try projectionWorkspace()
  defer { try? FileManager.default.removeItem(at: other) }
  let mapper = try LegacyNormalizedProjection(directory: other)
  await #expect(throws: FoundationStorageError.invalidFixture) {
    try await mapper.copy(
      projectionFixture(), snapshotID: projectionSnapshot, timeZoneID: "Not/AZone",
      referenceDate: projectionReference)
  }
}

@Test func normalizedProjectionPreservesEveryNullableLinkWithoutFabricatingParents() async throws {
  let relationshipFields: [String: [String]] = [
    "FoodItem": ["menuItem"], "MenuItem": ["restaurant"], "MenuItemModifier": ["menuItem"],
    "BuildableItemTemplate": ["restaurant"], "BuildComponentCategory": ["template"],
    "BuildComponentOption": ["category"], "DiaryEntry": ["foodItem"],
    "SavedMealItem": ["foodItem", "savedMeal"], "WeightEntry": ["progressEntry"],
    "ProgressEntry": ["weightEntry"], "ProgressPhoto": ["progressEntry"],
    "Note": ["linkedDiaryEntry"],
  ]
  let arrayFields: [String: [String]] = [
    "Restaurant": ["menuItems", "buildableTemplates"], "MenuItem": ["modifiers"],
    "BuildableItemTemplate": ["categories"], "BuildComponentCategory": ["options"],
    "SavedMeal": ["items"], "ProgressEntry": ["photos"],
  ]
  let rows = try projectionFixture().map { row in
    var f = try #require(JSONSerialization.jsonObject(with: row.payload) as? [String: Any])
    for field in relationshipFields[row.entity] ?? [] { f[field] = NSNull() }
    for field in arrayFields[row.entity] ?? [] { f[field] = [String]() }
    return LegacySnapshotRow(
      entity: row.entity, id: row.id,
      payload: try JSONSerialization.data(withJSONObject: f, options: [.sortedKeys]), references: []
    )
  }
  let workspace = try projectionWorkspace()
  defer { try? FileManager.default.removeItem(at: workspace) }
  let mapper = try LegacyNormalizedProjection(directory: workspace)
  let report = try await mapper.copy(
    rows, snapshotID: projectionSnapshot, timeZoneID: projectionZone,
    referenceDate: projectionReference)
  #expect(report.sourceRows == rows.count)
  #expect(report.diaryCalories == 550.15625)
  #expect(report.photos == 3)
  #expect(try await mapper.normalizedRows() == rows)
  let counts = try await projectionDatabase(workspace).read { db in
    try ["attachments", "food_component_groups", "projection_links", "sync_outbox"].map {
      try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \($0)")
    }
  }
  #expect(counts.allSatisfy { $0 == 0 })
}

@Test func normalizedProjectionRejectsAggregateOverflowBeforeCopying() async throws {
  let rows = try projectionFixture().map { row in
    guard row.entity == "DiaryEntry" else { return row }
    var f = try #require(JSONSerialization.jsonObject(with: row.payload) as? [String: Any])
    f["caloriesSnapshot"] = Double.greatestFiniteMagnitude
    return LegacySnapshotRow(
      entity: row.entity, id: row.id,
      payload: try JSONSerialization.data(withJSONObject: f, options: [.sortedKeys]),
      references: row.references)
  }
  let workspace = try projectionWorkspace()
  defer { try? FileManager.default.removeItem(at: workspace) }
  let mapper = try LegacyNormalizedProjection(directory: workspace)
  await #expect(throws: FoundationStorageError.invalidFixture) {
    try await mapper.copy(
      rows, snapshotID: projectionSnapshot, timeZoneID: projectionZone,
      referenceDate: projectionReference)
  }
  #expect(
    try await projectionDatabase(workspace).read {
      try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM accounts")
    } == 0)
}
