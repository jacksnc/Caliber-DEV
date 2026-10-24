import CryptoKit
import Foundation
import GRDB
import Testing

@testable import CaliberDatabase

private let recipeSnapshot = "0199c300-1000-7000-8000-000000000099"
private let recipeReference = Date(timeIntervalSince1970: 1_700_000_000.125)
private let recipeMealID = "00000000-0000-4000-8000-000000000002"

private func recipeProjectionRows(
  version: Int = 2, servings: Double = 2.5,
  cooked: Double? = 450.125, raw: Double? = 550.25
) throws -> [LegacySnapshotRow] {
  let food = "00000000-0000-4000-8000-000000000001"
  let item = "00000000-0000-4000-8000-000000000003"
  func row(_ entity: String, _ id: String, _ fields: [String: Any], _ links: [LegacyReference])
    throws -> LegacySnapshotRow
  {
    LegacySnapshotRow(
      entity: entity, id: id,
      payload: try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]),
      references: links.sorted { ($0.entity, $0.id) < ($1.entity, $1.id) })
  }
  var metadata: [String: Any] = ["name": "Synthetic recipe", "items": [item]]
  if version != 1 {
    metadata.merge([
      "payloadVersion": version, "servings": servings,
      "cookedYieldGrams": cooked as Any? ?? NSNull(), "rawBatchGrams": raw as Any? ?? NSNull(),
    ]) { _, v in v }
  }
  return try [
    row(
      "FoodItem", food,
      [
        "name": "Original ingredient", "calories": 350.125, "protein": 30.25,
        "carbs": 40.5, "fat": 11.125, "servingDescription": "Original portion",
        "sourceType": "generic", "isSavedToLibrary": true, "menuItem": NSNull(),
      ], []),
    row("SavedMeal", recipeMealID, metadata, [LegacyReference("SavedMealItem", item)]),
    row(
      "SavedMealItem", item, ["quantity": 1.25, "foodItem": food, "savedMeal": recipeMealID],
      [LegacyReference("FoodItem", food), LegacyReference("SavedMeal", recipeMealID)]),
  ]
}

private func recipeProjectionWorkspace() throws -> URL {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "RecipeProjectionTests-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  return directory
}
private func recipeProjectionDatabase(_ directory: URL) throws -> DatabaseQueue {
  try DatabaseQueue(
    path: directory.appendingPathComponent("normalized-rehearsal-v1/normalized-copy.sqlite").path)
}
private func recipeProjectionChange(
  _ rows: [LegacySnapshotRow], values: [String: Any], remove: String? = nil
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

@Test(arguments: ["servings only", "cooked only", "raw only", "both measured"])
func recipeProjectionRoundTripPreservesMeasuredAndUnknownWeights(_ kind: String) async throws {
  let rows: [LegacySnapshotRow]
  switch kind {
  case "servings only": rows = try recipeProjectionRows(cooked: nil, raw: nil)
  case "cooked only": rows = try recipeProjectionRows(servings: 1, raw: nil)
  case "raw only": rows = try recipeProjectionRows(servings: 1, cooked: nil)
  default: rows = try recipeProjectionRows()
  }
  let directory = try recipeProjectionWorkspace()
  defer { try? FileManager.default.removeItem(at: directory) }
  let archive = try LegacyShadowArchive(directory: directory.appendingPathComponent("archive"))
  let snapshot = try await archive.copy(rows)
  let projection = try LegacyNormalizedProjection(directory: directory)
  let result = try await projection.copy(
    rows, snapshotID: snapshot,
    timeZoneID: "America/New_York", referenceDate: recipeReference)
  #expect(result.sourceRows == 3 && result.canonicalRows == 2 && result.compatibilityRows == 3)
  #expect(result.warnings.contains { $0.contains("yield factors are not fabricated") })
  #expect(try await projection.normalizedRows() == rows)
  let id = try await projection.mappedID(entity: "SavedMeal", legacyID: recipeMealID)
  let reopened = try LegacyNormalizedProjection(directory: directory)
  #expect(
    try await reopened.copy(
      rows, snapshotID: snapshot,
      timeZoneID: "America/New_York", referenceDate: recipeReference) == result)
  #expect(try await reopened.mappedID(entity: "SavedMeal", legacyID: recipeMealID) == id)
  #expect(try await archive.read(snapshotID: snapshot) == rows)
  let db = try recipeProjectionDatabase(directory)
  let properties = try await db.read { d in
    try [
      Int.fetchOne(d, sql: "SELECT COUNT(*) FROM recipes"),
      Int.fetchOne(d, sql: "SELECT COUNT(*) FROM recipe_ingredients"),
      Int.fetchOne(d, sql: "SELECT COUNT(*) FROM sync_outbox"),
      Int.fetchOne(d, sql: "SELECT digest_version FROM projection_manifest"),
    ]
  }
  #expect(properties == [0, 0, 0, 2])
}

@Test func recipeProjectionFailureRollsBackMetadataAndCanRetry() async throws {
  let rows = try recipeProjectionRows()
  let directory = try recipeProjectionWorkspace()
  defer { try? FileManager.default.removeItem(at: directory) }
  let projection = try LegacyNormalizedProjection(directory: directory)
  let db = try recipeProjectionDatabase(directory)
  for index in [0, 1, 2] {
    await #expect(throws: FoundationStorageError.unavailable) {
      try await projection.copy(
        rows, snapshotID: recipeSnapshot, timeZoneID: "America/New_York",
        referenceDate: recipeReference, failAfter: index)
    }
    let counts = try await db.read { d in
      try [
        "accounts", "projection_manifest", "projection_source_rows", "legacy_id_map",
        "projection_saved_meal_metadata", "meal_templates",
      ].map {
        try Int.fetchOne(d, sql: "SELECT COUNT(*) FROM \($0)")
      }
    }
    #expect(counts.allSatisfy { $0 == 0 })
  }
  _ = try await projection.copy(
    rows, snapshotID: recipeSnapshot, timeZoneID: "America/New_York", referenceDate: recipeReference
  )
  #expect(try await projection.normalizedRows() == rows)
  let changed = try recipeProjectionRows(raw: 600.5)
  await #expect(throws: FoundationStorageError.differentFixture) {
    try await projection.copy(
      changed, snapshotID: recipeSnapshot, timeZoneID: "America/New_York",
      referenceDate: recipeReference)
  }
  #expect(try await projection.normalizedRows() == rows)
}

@Test(arguments: [
  "UPDATE projection_saved_meal_metadata SET servings=servings+1",
  "UPDATE projection_saved_meal_metadata SET cooked_yield_grams=NULL",
  "UPDATE projection_saved_meal_metadata SET raw_batch_grams=raw_batch_grams+1",
  "DELETE FROM projection_saved_meal_metadata", "UPDATE projection_manifest SET digest_version=1",
])
func recipeProjectionDetectsMetadataDeletionChangesAndDigestDowngrade(_ sql: String) async throws {
  let rows = try recipeProjectionRows()
  let directory = try recipeProjectionWorkspace()
  defer { try? FileManager.default.removeItem(at: directory) }
  let projection = try LegacyNormalizedProjection(directory: directory)
  _ = try await projection.copy(
    rows, snapshotID: recipeSnapshot, timeZoneID: "America/New_York", referenceDate: recipeReference
  )
  try await recipeProjectionDatabase(directory).write { try $0.execute(sql: sql) }
  await #expect(throws: FoundationStorageError.incompleteFixture) {
    try await projection.reconcile(
      rows, snapshotID: recipeSnapshot, timeZoneID: "America/New_York",
      referenceDate: recipeReference)
  }
  await #expect(throws: FoundationStorageError.incompleteFixture) {
    try await projection.copy(
      rows, snapshotID: recipeSnapshot, timeZoneID: "America/New_York",
      referenceDate: recipeReference)
  }
}

@Test(arguments: [
  "partial", "missing raw", "wrong version", "boolean version", "boolean servings",
  "zero servings", "negative cooked", "zero raw", "string raw", "unknown field", "default v2",
])
func recipeProjectionRejectsInvalidMetadataBeforeWriting(_ kind: String) async throws {
  let original = try recipeProjectionRows()
  let rows: [LegacySnapshotRow]
  switch kind {
  case "partial": rows = try recipeProjectionChange(original, values: [:], remove: "payloadVersion")
  case "missing raw":
    rows = try recipeProjectionChange(original, values: [:], remove: "rawBatchGrams")
  case "wrong version": rows = try recipeProjectionChange(original, values: ["payloadVersion": 3])
  case "boolean version":
    rows = try recipeProjectionChange(original, values: ["payloadVersion": true])
  case "boolean servings": rows = try recipeProjectionChange(original, values: ["servings": true])
  case "zero servings": rows = try recipeProjectionChange(original, values: ["servings": 0])
  case "negative cooked":
    rows = try recipeProjectionChange(original, values: ["cookedYieldGrams": -1])
  case "zero raw": rows = try recipeProjectionChange(original, values: ["rawBatchGrams": 0])
  case "string raw":
    rows = try recipeProjectionChange(original, values: ["rawBatchGrams": "550.25"])
  case "unknown field": rows = try recipeProjectionChange(original, values: ["inferredDensity": 1])
  default:
    rows = try recipeProjectionChange(
      original, values: ["servings": 1, "cookedYieldGrams": NSNull(), "rawBatchGrams": NSNull()])
  }
  let directory = try recipeProjectionWorkspace()
  defer { try? FileManager.default.removeItem(at: directory) }
  let projection = try LegacyNormalizedProjection(directory: directory)
  await #expect(throws: FoundationStorageError.invalidFixture) {
    try await projection.copy(
      rows, snapshotID: recipeSnapshot, timeZoneID: "America/New_York",
      referenceDate: recipeReference)
  }
  #expect(
    try await recipeProjectionDatabase(directory).read {
      try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM accounts")
    } == 0)
}

/// Frozen v4 framing/table list from 78691ed, independent of the new version-selection code.
/// The actual prior-binary disk-store/v4 upgrade is also exercised by the separate native probe.
private func recipeV4Digest(_ db: Database) throws -> String {
  let tables = [
    "accounts", "sync_context", "food_sources", "restaurants", "foods", "food_component_groups",
    "meal_slots", "meal_logs", "meal_templates", "weigh_ins", "check_ins", "notes", "attachments",
    "import_batches", "legacy_id_map", "projection_source_rows", "projection_links",
    "projection_food_portions", "projection_menu_portions", "projection_modifiers",
    "projection_categories", "projection_option_portions", "projection_diary",
    "projection_saved_items",
    "projection_weights", "projection_progress", "projection_photos", "projection_notes",
    "projection_profiles",
  ]
  var digest = SHA256()
  for table in tables {
    digest.update(data: Data(table.utf8))
    let order =
      table == "projection_links"
      ? "source_id,field,position" : table == "projection_source_rows" ? "entity,legacy_id" : "id"
    for row in try Row.fetchAll(db, sql: "SELECT * FROM \(table) ORDER BY \(order)") {
      for column in row.columnNames.sorted() {
        digest.update(data: Data(column.utf8))
        let value: DatabaseValue = row[column]
        let bytes: Data
        switch value.storage {
        case .null: bytes = Data("null".utf8)
        case .int64(let n): bytes = Data("i:\(n)".utf8)
        case .double(let n): bytes = Data("d:\(n.bitPattern)".utf8)
        case .string(let s): bytes = Data("s:".utf8) + Data(s.utf8)
        case .blob(let b): bytes = Data("b:".utf8) + b
        }
        digest.update(data: Data("\(bytes.count):".utf8))
        digest.update(data: bytes)
      }
    }
  }
  return digest.finalize().map { String(format: "%02x", $0) }.joined()
}

@Test func recipeMigrationPreservesCompletedV4TargetHashSourceBytesAndUUIDMappings() async throws {
  let rows = try recipeProjectionRows(version: 1)
  let directory = try recipeProjectionWorkspace()
  defer { try? FileManager.default.removeItem(at: directory) }
  let projection = try LegacyNormalizedProjection(directory: directory)
  _ = try await projection.copy(
    rows, snapshotID: recipeSnapshot, timeZoneID: "America/New_York", referenceDate: recipeReference
  )
  let id = try await projection.mappedID(entity: "SavedMeal", legacyID: recipeMealID)
  let db = try recipeProjectionDatabase(directory)
  // Recreate the exact v4 schema boundary; do not use the new digest implementation to bless it.
  let priorDigest = try await db.write { d in
    try d.execute(
      sql:
        "DROP TABLE projection_saved_meal_metadata; ALTER TABLE projection_manifest DROP COLUMN digest_version; DELETE FROM grdb_migrations WHERE identifier='v5_saved_meal_metadata'"
    )
    let digest = try recipeV4Digest(d)
    try d.execute(sql: "UPDATE projection_manifest SET target_digest=?", arguments: [digest])
    return digest
  }
  let reopened = try LegacyNormalizedProjection(directory: directory)
  let report = try await reopened.reconcile(
    rows, snapshotID: recipeSnapshot, timeZoneID: "America/New_York", referenceDate: recipeReference
  )
  #expect(report.sourceRows == 3 && report.compatibilityRows == 2)
  #expect(try await reopened.normalizedRows() == rows)
  #expect(try await reopened.mappedID(entity: "SavedMeal", legacyID: recipeMealID) == id)
  _ = try await reopened.copy(
    rows, snapshotID: recipeSnapshot, timeZoneID: "America/New_York", referenceDate: recipeReference
  )
  let after = try await db.read { d in
    try (
      String.fetchOne(d, sql: "SELECT target_digest FROM projection_manifest"),
      Int.fetchOne(d, sql: "SELECT digest_version FROM projection_manifest"),
      Int.fetchOne(d, sql: "SELECT COUNT(*) FROM projection_saved_meal_metadata"),
      Int.fetchOne(d, sql: "SELECT COUNT(*) FROM legacy_id_map")
    )
  }
  #expect(after.0 == priorDigest && after.1 == 1 && after.2 == 0 && after.3 == 3)
}
