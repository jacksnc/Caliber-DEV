import CoreFoundation
import CryptoKit
import Foundation
import GRDB

/// A rehearsal result, never permission to switch the application's live data store.
public struct LegacyProjectionReport: Equatable, Sendable {
  public let sourceRows: Int
  /// Source records represented in at least one canonical table (counts can overlap compatibility).
  public let canonicalRows: Int
  public let compatibilityRows: Int
  public let diaryCalories: Double
  public let diaryProtein: Double
  public let diaryCarbs: Double
  public let diaryFat: Double
  public let photos: Int
  public let photoBytes: Int64
  public let warnings: [String]
}

/// Copies supported legacy values to a NEW, explicitly named, local rehearsal database.
/// It neither discovers SwiftData files nor opens core.sqlite, Stack or any cloud service.
/// Missing gram weights remain unknown: per-portion values never masquerade as per-100g data.
public actor LegacyNormalizedProjection {
  private let queue: DatabaseQueue
  private static let account = "0199c300-1000-7000-8000-000000000010"
  private static let source = "0199c300-1000-7000-8000-000000000011"
  private static let batch = "0199c300-1000-7000-8000-000000000012"

  public init(directory: URL) throws {
    let target = directory.appendingPathComponent("normalized-rehearsal-v1", isDirectory: true)
    let file = target.appendingPathComponent("normalized-copy.sqlite")
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    var excluded = target
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try excluded.setResourceValues(values)
    #if os(iOS)
      try FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.complete], ofItemAtPath: target.path)
    #endif
    // Refuse an existing arbitrary/live/demo database before running any migrations on it.
    if FileManager.default.fileExists(atPath: file.path) {
      var readOnly = Configuration()
      readOnly.readonly = true
      let existing = try DatabaseQueue(path: file.path, configuration: readOnly)
      let recognized = try existing.read { db in
        try db.tableExists("projection_identity")
          && String.fetchOne(db, sql: "SELECT purpose FROM projection_identity")
            == "legacy-normalized-rehearsal-v1"
      }
      guard recognized else { throw FoundationStorageError.differentFixture }
    }
    var configuration = Configuration()
    configuration.prepareDatabase { db in
      try db.execute(
        sql: "PRAGMA foreign_keys=ON; PRAGMA recursive_triggers=ON; PRAGMA synchronous=FULL")
    }
    queue = try DatabaseQueue(path: file.path, configuration: configuration)
    var migrator = try DatabaseSchema.migrator(domain: .core)
    migrator.registerMigration("v4_legacy_normalized_rehearsal") { db in
      try db.execute(sql: Self.compatibilitySchema)
    }
    try migrator.migrate(queue)
  }

  /// One immutable source boundary per rehearsal target. A changed source needs a NEW target.
  /// `timeZoneID` is a required explicit assumption; legacy observations have no historical zone.
  /// `referenceDate` is import metadata only, never a fabricated date for a legacy observation.
  public func copy(
    _ rows: [LegacySnapshotRow], snapshotID: String, timeZoneID: String,
    referenceDate: Date, failAfter: Int? = nil
  ) throws -> LegacyProjectionReport {
    let input = try ProjectionInput(
      rows, snapshotID: snapshotID, timeZoneID: timeZoneID, referenceDate: referenceDate)
    try queue.write { db in
      if try db.tableExists("projection_manifest"),
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM projection_manifest") == 1
      {
        try Self.checkManifest(db, input)
        return
      }
      guard try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM accounts") == 0,
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM foundation_demo_manifest") == 0
      else { throw FoundationStorageError.differentFixture }
      try insert(
        db, "projection_manifest",
        [
          "singleton": 1, "snapshot_id": snapshotID, "source_digest": input.digest,
          "timezone": timeZoneID, "reference_date": referenceDate.timeIntervalSince1970,
          "row_count": rows.count,
        ])
      try Self.seedIdentity(db, timestamp: input.importTimestamp)
      try Self.add(
        db, "import_batches",
        [
          "format": "legacy-normalized-rehearsal", "file_digest": input.digest,
          "status": "verified", "total_rows": rows.count, "accepted_rows": rows.count,
          "source_schema_version": "legacy-public-models-v1", "validation_digest": input.digest,
          "completed_at": input.importTimestamp,
        ], id: Self.batch)
      for row in input.rows {
        let id = databaseUUID()
        try Self.add(
          db, "legacy_id_map",
          [
            "batch_id": Self.batch, "source_entity": row.entity, "legacy_identifier": row.id,
            "destination_table": Self.destination(row.entity), "destination_id": id,
          ])
        try insert(
          db, "projection_source_rows",
          [
            "entity": row.entity, "legacy_id": row.id, "target_id": id,
            "payload": row.payload, "payload_digest": ProjectionInput.hash(row.payload),
            "links": try ProjectionInput.linkData(row.references),
          ])
      }
      // Deferred FKs allow original bidirectional links without order-dependent placeholder rows.
      for (index, row) in input.rows.enumerated() {
        if failAfter == index { throw FoundationStorageError.unavailable }
        try Self.project(db, row: row, input: input)
      }
      guard try Row.fetchAll(db, sql: "PRAGMA foreign_key_check").isEmpty else {
        throw FoundationStorageError.incompleteFixture
      }
      // Verify from typed domain columns before commit; no partial copy survives a failure.
      _ = try Self.verify(db, input)
      try db.execute(
        sql:
          "UPDATE sync_context SET mode='local',logical_clock=logical_clock+1 WHERE account_id=?",
        arguments: [Self.account])
      try Self.persistTargetDigest(db)
    }
    return try queue.read { try Self.verify($0, input) }
  }

  public func reconcile(
    _ rows: [LegacySnapshotRow], snapshotID: String, timeZoneID: String, referenceDate: Date
  ) throws -> LegacyProjectionReport {
    let input = try ProjectionInput(
      rows, snapshotID: snapshotID, timeZoneID: timeZoneID, referenceDate: referenceDate)
    return try queue.read {
      try Self.checkManifest($0, input)
      return try Self.verify($0, input)
    }
  }

  public func mappedID(entity: String, legacyID: String) throws -> String? {
    try queue.read {
      try String.fetchOne(
        $0,
        sql: "SELECT target_id FROM projection_source_rows WHERE entity=? AND legacy_id=?",
        arguments: [entity, legacyID])
    }
  }

  /// Reconstructs public legacy fields from typed normalized domain values, not archived JSON.
  public func normalizedRows(entity: String? = nil) throws -> [LegacySnapshotRow] {
    try queue.read { db in
      let result = try Self.reconstructedRows(db)
      return entity.map { name in result.filter { $0.entity == name } } ?? result
    }
  }

  private static func add(
    _ db: Database, _ table: String, _ fields: [String: (any DatabaseValueConvertible)?],
    id: String = databaseUUID()
  ) throws {
    guard
      let reference = try Double.fetchOne(
        db, sql: "SELECT reference_date FROM projection_manifest WHERE singleton=1")
    else {
      throw FoundationStorageError.incompleteFixture
    }
    let timestamp = Int64(reference * 1000)
    try insert(
      db, table,
      [
        "id": id, "account_id": account, "created_at": timestamp, "updated_at": timestamp,
        "source": "import",
      ].merging(fields) { _, value in value })
  }

  private static func seedIdentity(_ db: Database, timestamp: Int64) throws {
    try db.execute(sql: "PRAGMA defer_foreign_keys=ON")
    try add(db, "sync_context", ["mode": "remote_apply"])
    try insert(
      db, "accounts",
      ["id": account, "created_at": timestamp, "updated_at": timestamp, "source": "import"])
    try add(
      db, "food_sources",
      [
        "name": "Legacy local library", "source_kind": "user",
        "license_identifier": "legacy-provenance-unknown",
        "attribution": "Owner's existing local data; external nutrition provenance not verified",
      ], id: source)
  }

  private static func destination(_ entity: String) -> String {
    switch entity {
    case "Restaurant": return "restaurants"
    case "FoodItem", "MenuItem", "BuildableItemTemplate", "BuildComponentOption": return "foods"
    case "BuildComponentCategory": return "projection_categories"
    case "MenuItemModifier": return "projection_modifiers"
    case "DiaryEntry": return "projection_diary"
    case "SavedMeal": return "meal_templates"
    case "SavedMealItem": return "projection_saved_items"
    case "WeightEntry": return "weigh_ins"
    case "ProgressEntry": return "check_ins"
    case "ProgressPhoto": return "projection_photos"
    case "Note": return "notes"
    default: return "projection_profiles"
    }
  }

  private static func id(_ db: Database, _ entity: String, _ legacy: String) throws -> String {
    guard
      let id = try String.fetchOne(
        db,
        sql: "SELECT target_id FROM projection_source_rows WHERE entity=? AND legacy_id=?",
        arguments: [entity, legacy])
    else { throw FoundationStorageError.incompleteFixture }
    return id
  }

  private static func project(_ db: Database, row: LegacySnapshotRow, input: ProjectionInput) throws
  {
    let f = try ProjectionFields(row.payload)
    let target = try id(db, row.entity, row.id)
    func reference(_ field: String, _ entity: String) throws -> String? {
      try f.optionalString(field).map { try id(db, entity, $0) }
    }
    func sidecar(_ table: String, _ fields: [String: (any DatabaseValueConvertible)?]) throws {
      try insert(db, table, ["id": target].merging(fields) { _, value in value })
    }
    func food(_ kind: String, restaurant: String? = nil, custom: Bool = false) throws {
      let name = try f.string("name")
      try add(
        db, "foods",
        [
          "name": name,
          "normalized_name": name.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")),
          "kind": kind, "source_id": source, "restaurant_id": restaurant,
          "quality_rank": 0, "is_custom": custom,
          "menu_category": row.entity == "MenuItem" ? try f.string("category") : nil,
        ], id: target)
    }
    func macros(_ suffix: String = "") throws -> [String: (any DatabaseValueConvertible)?] {
      try Dictionary(
        uniqueKeysWithValues: ["calories", "protein", "carbs", "fat"].map {
          ($0, try f.number($0 + suffix) as (any DatabaseValueConvertible)?)
        })
    }
    func timed() throws -> [String: (any DatabaseValueConvertible)?] {
      let date = Date(timeIntervalSinceReferenceDate: try f.number("dateReference"))
      return [
        "occurred_at": Int64(date.timeIntervalSince1970 * 1000),
        "tz": input.timeZoneID, "local_date": input.localDay(date),
      ]
    }
    switch row.entity {
    case "Restaurant":
      try add(db, "restaurants", ["name": try f.string("name")], id: target)
    case "FoodItem":
      // The old generic-food model did not record a custom/official distinction.
      try food("food")
      try sidecar(
        "projection_food_portions",
        try macros().merging([
          "serving_description": f.string("servingDescription"),
          "source_type": f.string("sourceType"), "is_saved": f.boolean("isSavedToLibrary"),
          "menu_food_id": reference("menuItem", "MenuItem"),
        ]) { _, v in v })
    case "MenuItem":
      try food(
        "menu_item", restaurant: reference("restaurant", "Restaurant"),
        custom: f.boolean("isCustom"))
      try sidecar("projection_menu_portions", try macros())
    case "MenuItemModifier":
      try sidecar(
        "projection_modifiers",
        [
          "name": try f.string("name"), "menu_food_id": reference("menuItem", "MenuItem"),
          "calories_delta": f.number("calorieDelta"), "protein_delta": f.number("proteinDelta"),
          "carbs_delta": f.number("carbDelta"), "fat_delta": f.number("fatDelta"),
        ])
    case "BuildableItemTemplate":
      try food("builder", restaurant: reference("restaurant", "Restaurant"))
    case "BuildComponentCategory":
      let parent = try reference("template", "BuildableItemTemplate")
      let fields: [String: (any DatabaseValueConvertible)?] = [
        "name": try f.string("name"), "selection_mode": try f.string("selectionType"),
        "required": try f.boolean("isRequired"), "position": try f.integer("sortOrder"),
      ]
      try sidecar(
        "projection_categories", fields.merging(["template_food_id": parent]) { _, v in v })
      if let parent {
        try add(
          db, "food_component_groups", fields.merging(["food_id": parent]) { _, v in v }, id: target
        )
      }
    case "BuildComponentOption":
      try food("food")
      try sidecar(
        "projection_option_portions",
        try macros().merging([
          "category_id": reference("category", "BuildComponentCategory"),
          "supports_double": f.boolean("supportsDouble"),
        ]) { _, v in v })
    case "DiaryEntry":
      let meal = try f.string("mealType")
      let slot: String
      if let existing = try String.fetchOne(
        db, sql: "SELECT id FROM meal_slots WHERE name=?", arguments: [meal])
      {
        slot = existing
      } else {
        slot = databaseUUID()
        try add(
          db, "meal_slots",
          [
            "name": meal,
            "position": ["breakfast", "lunch", "dinner", "snack"].firstIndex(of: meal) ?? 3,
          ], id: slot)
      }
      try add(
        db, "meal_logs",
        try timed().merging([
          "meal_slot_id": slot, "state": "eaten", "notes": f.optionalString("note"),
        ]) { _, v in v }, id: target)
      try sidecar(
        "projection_diary",
        try macros("Snapshot").merging([
          "meal_log_id": target, "food_id": reference("foodItem", "FoodItem"),
          "quantity": f.number("quantity"), "date_reference": f.number("dateReference"),
        ]) { _, v in v })
    case "SavedMeal":
      try add(db, "meal_templates", ["name": try f.string("name")], id: target)
    case "SavedMealItem":
      try sidecar(
        "projection_saved_items",
        [
          "meal_template_id": try reference("savedMeal", "SavedMeal"),
          "food_id": reference("foodItem", "FoodItem"), "quantity": f.number("quantity"),
        ])
    case "WeightEntry":
      try add(
        db, "weigh_ins",
        try timed().merging([
          "weight_kg": f.number("weightKG"), "entered_value": f.numericText("enteredValue"),
          "entered_unit": "lb",
        ]) { _, v in v }, id: target)
      try sidecar(
        "projection_weights",
        [
          "progress_id": try reference("progressEntry", "ProgressEntry"),
          "date_reference": f.number("dateReference"),
        ])
    case "ProgressEntry":
      try add(
        db, "check_ins",
        try timed().merging([
          "weigh_in_id": reference("weightEntry", "WeightEntry"), "notes": f.string("notes"),
        ]) { _, v in v }, id: target)
      try sidecar("projection_progress", ["date_reference": try f.number("dateReference")])
    case "ProgressPhoto":
      let bytes = try f.photoData()
      let progress = try reference("progressEntry", "ProgressEntry")
      try sidecar(
        "projection_photos",
        [
          "progress_id": progress, "image_bytes": bytes,
          "position": f.integer("sortOrder"), "bytes_digest": ProjectionInput.hash(bytes),
        ])
      if let progress {
        // The legacy snapshot has bytes, not MIME/EXIF/biometric metadata. Record that honestly.
        try add(
          db, "attachments",
          [
            "owner_table": "check_ins", "owner_id": progress,
            "local_locator": "projection_photos:" + target,
            "media_type": "application/octet-stream", "byte_count": bytes.count,
            "sha256": ProjectionInput.hash(bytes), "sort_order": f.integer("sortOrder"),
            "metadata_stripped": false, "biometric_required": true,
          ], id: target)
      }
    case "Note":
      let diary = try reference("linkedDiaryEntry", "DiaryEntry")
      try add(
        db, "notes",
        try timed().merging([
          "text": f.string("text"), "owner_table": diary == nil ? nil : "meal_logs",
          "owner_id": diary,
        ]) { _, v in v }, id: target)
      try sidecar(
        "projection_notes",
        [
          "date_reference": try f.number("dateReference"), "diary_id": diary,
        ])
    case "UserProfile":
      try sidecar(
        "projection_profiles",
        [
          "height_inches": try f.number("heightInInches"),
          "starting_weight_lb": f.number("startingWeight"),
          "activity_level": f.string("activityLevel"),
          "calorie_goal": f.integer("dailyCalorieGoal"),
          "protein_goal": f.number("proteinGoal"), "carbs_goal": f.number("carbGoal"),
          "fat_goal": f.number("fatGoal"),
        ])
      if input.hasSingleUsableHeight {
        try db.execute(
          sql:
            "UPDATE accounts SET height_cm=?,entered_height_value=?,entered_height_unit='in',logical_clock=logical_clock+1 WHERE id=?",
          arguments: [
            try f.number("heightInInches") * 2.54, f.numericText("heightInInches"), account,
          ])
      }
    default: throw FoundationStorageError.invalidFixture
    }
    // Preserve relationship order and null parent/orphan semantics without manufacturing parents.
    for link in try input.links(row) {
      try insert(
        db, "projection_links",
        [
          "source_id": target, "field": link.field, "position": link.position,
          "target_id": id(db, link.entity, link.id),
        ])
    }
  }
}

extension LegacyNormalizedProjection {
  private static let compatibilitySchema = """
    CREATE TABLE projection_identity(purpose TEXT PRIMARY KEY CHECK(purpose='legacy-normalized-rehearsal-v1')) STRICT;
    INSERT INTO projection_identity VALUES('legacy-normalized-rehearsal-v1');
    CREATE TABLE projection_manifest(singleton INTEGER PRIMARY KEY CHECK(singleton=1),snapshot_id TEXT NOT NULL,source_digest TEXT NOT NULL,timezone TEXT NOT NULL,reference_date REAL NOT NULL,row_count INTEGER NOT NULL,target_digest TEXT) STRICT;
    CREATE TABLE projection_source_rows(entity TEXT NOT NULL,legacy_id TEXT NOT NULL,target_id TEXT NOT NULL UNIQUE,payload BLOB NOT NULL,payload_digest TEXT NOT NULL,links BLOB NOT NULL,PRIMARY KEY(entity,legacy_id)) STRICT;
    CREATE TABLE projection_links(source_id TEXT NOT NULL REFERENCES projection_source_rows(target_id) DEFERRABLE INITIALLY DEFERRED,field TEXT NOT NULL,position INTEGER NOT NULL,target_id TEXT NOT NULL REFERENCES projection_source_rows(target_id) DEFERRABLE INITIALLY DEFERRED,PRIMARY KEY(source_id,field,position),UNIQUE(source_id,field,target_id)) STRICT;
    CREATE TABLE projection_food_portions(id TEXT PRIMARY KEY REFERENCES foods(id) DEFERRABLE INITIALLY DEFERRED,calories REAL NOT NULL,protein REAL NOT NULL,carbs REAL NOT NULL,fat REAL NOT NULL,serving_description TEXT NOT NULL,source_type TEXT NOT NULL,is_saved INTEGER NOT NULL CHECK(is_saved IN(0,1)),menu_food_id TEXT REFERENCES foods(id) DEFERRABLE INITIALLY DEFERRED) STRICT;
    CREATE TABLE projection_menu_portions(id TEXT PRIMARY KEY REFERENCES foods(id) DEFERRABLE INITIALLY DEFERRED,calories REAL NOT NULL,protein REAL NOT NULL,carbs REAL NOT NULL,fat REAL NOT NULL) STRICT;
    CREATE TABLE projection_modifiers(id TEXT PRIMARY KEY REFERENCES projection_source_rows(target_id) DEFERRABLE INITIALLY DEFERRED,name TEXT NOT NULL,menu_food_id TEXT REFERENCES foods(id) DEFERRABLE INITIALLY DEFERRED,calories_delta REAL NOT NULL,protein_delta REAL NOT NULL,carbs_delta REAL NOT NULL,fat_delta REAL NOT NULL) STRICT;
    CREATE TABLE projection_categories(id TEXT PRIMARY KEY REFERENCES projection_source_rows(target_id) DEFERRABLE INITIALLY DEFERRED,template_food_id TEXT REFERENCES foods(id) DEFERRABLE INITIALLY DEFERRED,name TEXT NOT NULL,selection_mode TEXT NOT NULL CHECK(selection_mode IN('single','multiple')),required INTEGER NOT NULL CHECK(required IN(0,1)),position INTEGER NOT NULL) STRICT;
    CREATE TABLE projection_option_portions(id TEXT PRIMARY KEY REFERENCES foods(id) DEFERRABLE INITIALLY DEFERRED,category_id TEXT REFERENCES projection_categories(id) DEFERRABLE INITIALLY DEFERRED,calories REAL NOT NULL,protein REAL NOT NULL,carbs REAL NOT NULL,fat REAL NOT NULL,supports_double INTEGER NOT NULL CHECK(supports_double IN(0,1))) STRICT;
    CREATE TABLE projection_diary(id TEXT PRIMARY KEY REFERENCES projection_source_rows(target_id) DEFERRABLE INITIALLY DEFERRED,meal_log_id TEXT NOT NULL REFERENCES meal_logs(id) DEFERRABLE INITIALLY DEFERRED,food_id TEXT REFERENCES foods(id) DEFERRABLE INITIALLY DEFERRED,date_reference REAL NOT NULL,quantity REAL NOT NULL,calories REAL NOT NULL,protein REAL NOT NULL,carbs REAL NOT NULL,fat REAL NOT NULL) STRICT;
    CREATE TABLE projection_saved_items(id TEXT PRIMARY KEY REFERENCES projection_source_rows(target_id) DEFERRABLE INITIALLY DEFERRED,meal_template_id TEXT REFERENCES meal_templates(id) DEFERRABLE INITIALLY DEFERRED,food_id TEXT REFERENCES foods(id) DEFERRABLE INITIALLY DEFERRED,quantity REAL NOT NULL) STRICT;
    CREATE TABLE projection_weights(id TEXT PRIMARY KEY REFERENCES weigh_ins(id) DEFERRABLE INITIALLY DEFERRED,progress_id TEXT REFERENCES check_ins(id) DEFERRABLE INITIALLY DEFERRED,date_reference REAL NOT NULL) STRICT;
    CREATE TABLE projection_progress(id TEXT PRIMARY KEY REFERENCES check_ins(id) DEFERRABLE INITIALLY DEFERRED,date_reference REAL NOT NULL) STRICT;
    CREATE TABLE projection_photos(id TEXT PRIMARY KEY REFERENCES projection_source_rows(target_id) DEFERRABLE INITIALLY DEFERRED,progress_id TEXT REFERENCES check_ins(id) DEFERRABLE INITIALLY DEFERRED,image_bytes BLOB NOT NULL,position INTEGER NOT NULL,bytes_digest TEXT NOT NULL) STRICT;
    CREATE TABLE projection_notes(id TEXT PRIMARY KEY REFERENCES notes(id) DEFERRABLE INITIALLY DEFERRED,date_reference REAL NOT NULL,diary_id TEXT REFERENCES projection_diary(id) DEFERRABLE INITIALLY DEFERRED) STRICT;
    CREATE TABLE projection_profiles(id TEXT PRIMARY KEY REFERENCES projection_source_rows(target_id) DEFERRABLE INITIALLY DEFERRED,height_inches REAL NOT NULL,starting_weight_lb REAL NOT NULL,activity_level TEXT NOT NULL,calorie_goal INTEGER NOT NULL,protein_goal REAL NOT NULL,carbs_goal REAL NOT NULL,fat_goal REAL NOT NULL) STRICT;
    """

  private static let targetTables = [
    "accounts", "sync_context", "food_sources", "restaurants", "foods", "food_component_groups",
    "meal_slots", "meal_logs", "meal_templates", "weigh_ins", "check_ins", "notes", "attachments",
    "import_batches", "legacy_id_map", "projection_source_rows", "projection_links",
    "projection_food_portions", "projection_menu_portions", "projection_modifiers",
    "projection_categories", "projection_option_portions", "projection_diary",
    "projection_saved_items",
    "projection_weights", "projection_progress", "projection_photos", "projection_notes",
    "projection_profiles",
  ]

  private static func targetDigest(_ db: Database) throws -> String {
    var digest = SHA256()
    for table in targetTables {
      digest.update(data: Data(table.utf8))
      for row in try Row.fetchAll(
        db,
        sql:
          "SELECT * FROM \(table) ORDER BY \(table == "projection_links" ? "source_id,field,position" : table == "projection_source_rows" ? "entity,legacy_id" : "id")"
      ) {
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

  private static func persistTargetDigest(_ db: Database) throws {
    try db.execute(
      sql: "UPDATE projection_manifest SET target_digest=?", arguments: [try targetDigest(db)])
  }

  private static func checkManifest(_ db: Database, _ input: ProjectionInput) throws {
    guard
      let row = try Row.fetchOne(db, sql: "SELECT * FROM projection_manifest WHERE singleton=1"),
      row["snapshot_id"] as String == input.snapshotID,
      row["source_digest"] as String == input.digest,
      row["timezone"] as String == input.timeZoneID,
      row["reference_date"] as Double == input.referenceDate.timeIntervalSince1970,
      row["row_count"] as Int == input.rows.count
    else { throw FoundationStorageError.differentFixture }
    guard try row["target_digest"] as String? == targetDigest(db) else {
      throw FoundationStorageError.incompleteFixture
    }
  }

  private static func verify(_ db: Database, _ input: ProjectionInput) throws
    -> LegacyProjectionReport
  {
    let stored = try Row.fetchAll(
      db, sql: "SELECT * FROM projection_source_rows ORDER BY entity,legacy_id")
    guard stored.count == input.rows.count else { throw FoundationStorageError.incompleteFixture }
    for (stored, original) in zip(stored, input.rows) {
      let payload: Data = stored["payload"]
      let links: Data = stored["links"]
      guard stored["entity"] as String == original.entity,
        stored["legacy_id"] as String == original.id, payload == original.payload,
        stored["payload_digest"] as String == ProjectionInput.hash(payload),
        try JSONDecoder().decode([LegacyReference].self, from: links)
          == original.references.sorted(by: ProjectionInput.linkOrder)
      else { throw FoundationStorageError.incompleteFixture }
    }
    let normalized = try reconstructedRows(db)
    guard normalized.count == input.rows.count else {
      throw FoundationStorageError.incompleteFixture
    }
    for (actual, original) in zip(normalized, input.rows) {
      let a = try JSONSerialization.jsonObject(with: actual.payload) as? NSDictionary
      let b = try JSONSerialization.jsonObject(with: original.payload) as? NSDictionary
      guard actual.entity == original.entity, actual.id == original.id, a == b,
        actual.references == original.references.sorted(by: ProjectionInput.linkOrder)
      else { throw FoundationStorageError.incompleteFixture }
    }
    guard try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sync_outbox") == 0,
      try Row.fetchAll(db, sql: "PRAGMA foreign_key_check").isEmpty,
      try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM food_logs") == 0,
      try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM food_nutrients") == 0
    else { throw FoundationStorageError.incompleteFixture }
    let totals = try Row.fetchOne(
      db,
      sql:
        "SELECT COALESCE(SUM(calories),0) c,COALESCE(SUM(protein),0) p,COALESCE(SUM(carbs),0) h,COALESCE(SUM(fat),0) f FROM projection_diary"
    )!
    let photo = try Row.fetchOne(
      db, sql: "SELECT COUNT(*) n,COALESCE(SUM(length(image_bytes)),0) b FROM projection_photos")!
    let canonical = input.rows.filter { row in
      [
        "Restaurant", "FoodItem", "MenuItem", "BuildableItemTemplate", "BuildComponentOption",
        "DiaryEntry", "SavedMeal", "WeightEntry", "ProgressEntry", "Note",
      ].contains(row.entity)
        || (row.entity == "BuildComponentCategory"
          && (try? ProjectionFields(row.payload).optionalString("template")) != nil)
        || (row.entity == "ProgressPhoto"
          && (try? ProjectionFields(row.payload).optionalString("progressEntry")) != nil)
        || (row.entity == "UserProfile" && input.hasSingleUsableHeight)
    }.count
    let compatibility = input.rows.filter {
      !["Restaurant", "BuildableItemTemplate", "SavedMeal"].contains($0.entity)
    }.count
    return LegacyProjectionReport(
      sourceRows: input.rows.count, canonicalRows: canonical, compatibilityRows: compatibility,
      diaryCalories: totals["c"], diaryProtein: totals["p"], diaryCarbs: totals["h"],
      diaryFat: totals["f"],
      photos: photo["n"], photoBytes: photo["b"], warnings: input.warnings)
  }

  private static func reconstructedRows(_ db: Database) throws -> [LegacySnapshotRow] {
    let sources = try Row.fetchAll(
      db,
      sql: "SELECT entity,legacy_id,target_id FROM projection_source_rows ORDER BY entity,legacy_id"
    )
    let legacyIDs = Dictionary(
      uniqueKeysWithValues: sources.map { ($0["target_id"] as String, $0["legacy_id"] as String) })
    func one(_ table: String, _ id: String) throws -> Row {
      guard
        let row = try Row.fetchOne(db, sql: "SELECT * FROM \(table) WHERE id=?", arguments: [id])
      else {
        throw FoundationStorageError.incompleteFixture
      }
      return row
    }
    func value(_ row: Row, _ column: String) -> Any {
      let v: DatabaseValue = row[column]
      switch v.storage {
      case .null: return NSNull()
      case .int64(let n): return n
      case .double(let n): return n
      case .string(let s): return s
      case .blob(let d): return d
      }
    }
    func fields(_ row: Row, _ map: [String: String], booleans: Set<String> = []) -> [String: Any] {
      Dictionary(
        uniqueKeysWithValues: map.map { field, column in
          (field, booleans.contains(field) ? (row[column] as Bool) : value(row, column))
        })
    }
    func ref(_ row: Row, _ column: String) throws -> Any {
      guard let id: String = row[column] else { return NSNull() }
      guard let original = legacyIDs[id] else { throw FoundationStorageError.incompleteFixture }
      return original
    }
    var result: [LegacySnapshotRow] = []
    for source in sources {
      let entity: String = source["entity"]
      let target: String = source["target_id"]
      var f: [String: Any] = [:]
      func set(_ row: Row, _ map: [String: String], booleans: Set<String> = []) {
        f.merge(fields(row, map, booleans: booleans)) { _, v in v }
      }
      func array(_ field: String) throws -> [String] {
        try String.fetchAll(
          db,
          sql:
            "SELECT target_id FROM projection_links WHERE source_id=? AND field=? ORDER BY position",
          arguments: [target, field]
        ).map {
          guard let original = legacyIDs[$0] else { throw FoundationStorageError.incompleteFixture }
          return original
        }
      }
      func macros(_ row: Row, suffix: String = "") {
        for column in ["calories", "protein", "carbs", "fat"] {
          f[column + suffix] = value(row, column)
        }
      }
      switch entity {
      case "Restaurant":
        set(try one("restaurants", target), ["name": "name"])
        f["menuItems"] = try array("menuItems")
        f["buildableTemplates"] = try array("buildableTemplates")
      case "FoodItem":
        set(try one("foods", target), ["name": "name"])
        let r = try one("projection_food_portions", target)
        macros(r)
        set(
          r,
          [
            "servingDescription": "serving_description", "sourceType": "source_type",
            "isSavedToLibrary": "is_saved",
          ], booleans: ["isSavedToLibrary"])
        f["menuItem"] = try ref(r, "menu_food_id")
      case "MenuItem":
        let r = try one("foods", target)
        set(
          r, ["name": "name", "category": "menu_category", "isCustom": "is_custom"],
          booleans: ["isCustom"])
        f["restaurant"] = try ref(r, "restaurant_id")
        f["modifiers"] = try array("modifiers")
        macros(try one("projection_menu_portions", target))
      case "MenuItemModifier":
        let r = try one("projection_modifiers", target)
        set(
          r,
          [
            "name": "name", "calorieDelta": "calories_delta", "proteinDelta": "protein_delta",
            "carbDelta": "carbs_delta", "fatDelta": "fat_delta",
          ])
        f["menuItem"] = try ref(r, "menu_food_id")
      case "BuildableItemTemplate":
        let r = try one("foods", target)
        set(r, ["name": "name"])
        f["restaurant"] = try ref(r, "restaurant_id")
        f["categories"] = try array("categories")
      case "BuildComponentCategory":
        let r = try one("projection_categories", target)
        set(
          r,
          [
            "name": "name", "selectionType": "selection_mode", "isRequired": "required",
            "sortOrder": "position",
          ], booleans: ["isRequired"])
        f["template"] = try ref(r, "template_food_id")
        f["options"] = try array("options")
      case "BuildComponentOption":
        set(try one("foods", target), ["name": "name"])
        let r = try one("projection_option_portions", target)
        macros(r)
        set(r, ["supportsDouble": "supports_double"], booleans: ["supportsDouble"])
        f["category"] = try ref(r, "category_id")
      case "DiaryEntry":
        let r = try one("projection_diary", target)
        set(r, ["dateReference": "date_reference", "quantity": "quantity"])
        macros(r, suffix: "Snapshot")
        f["foodItem"] = try ref(r, "food_id")
        let meal = try one("meal_logs", target)
        f["note"] = value(meal, "notes")
        let slot: String = meal["meal_slot_id"]
        f["mealType"] = value(try one("meal_slots", slot), "name")
      case "SavedMeal":
        set(try one("meal_templates", target), ["name": "name"])
        f["items"] = try array("items")
      case "SavedMealItem":
        let r = try one("projection_saved_items", target)
        set(r, ["quantity": "quantity"])
        f["foodItem"] = try ref(r, "food_id")
        f["savedMeal"] = try ref(r, "meal_template_id")
      case "WeightEntry":
        let r = try one("weigh_ins", target)
        set(r, ["weightKG": "weight_kg", "enteredUnit": "entered_unit"])
        guard let weight = Double(r["entered_value"] as String) else {
          throw FoundationStorageError.incompleteFixture
        }
        f["enteredValue"] = weight
        let side = try one("projection_weights", target)
        set(side, ["dateReference": "date_reference"])
        f["progressEntry"] = try ref(side, "progress_id")
      case "ProgressEntry":
        let r = try one("check_ins", target)
        set(r, ["notes": "notes"])
        f["weightEntry"] = try ref(r, "weigh_in_id")
        set(try one("projection_progress", target), ["dateReference": "date_reference"])
        f["photos"] = try array("photos")
      case "ProgressPhoto":
        let r = try one("projection_photos", target)
        let bytes: Data = r["image_bytes"]
        guard ProjectionInput.hash(bytes) == r["bytes_digest"] as String else {
          throw FoundationStorageError.incompleteFixture
        }
        f["imageDataBase64"] = bytes.base64EncodedString()
        set(r, ["sortOrder": "position"])
        f["progressEntry"] = try ref(r, "progress_id")
      case "Note":
        set(try one("notes", target), ["text": "text"])
        let r = try one("projection_notes", target)
        set(r, ["dateReference": "date_reference"])
        f["linkedDiaryEntry"] = try ref(r, "diary_id")
      case "UserProfile":
        set(
          try one("projection_profiles", target),
          [
            "heightInInches": "height_inches", "startingWeight": "starting_weight_lb",
            "activityLevel": "activity_level", "dailyCalorieGoal": "calorie_goal",
            "proteinGoal": "protein_goal", "carbGoal": "carbs_goal", "fatGoal": "fat_goal",
          ])
      default: throw FoundationStorageError.incompleteFixture
      }
      let payload = try JSONSerialization.data(withJSONObject: f, options: [.sortedKeys])
      let row = LegacySnapshotRow(
        entity: entity, id: source["legacy_id"], payload: payload, references: [])
      let refs = try ProjectionInput.relationships(row).map { LegacyReference($0.entity, $0.id) }
        .sorted(by: ProjectionInput.linkOrder)
      result.append(
        LegacySnapshotRow(entity: row.entity, id: row.id, payload: payload, references: refs))
    }
    return result
  }
}

private struct ProjectionFields {
  let values: [String: Any]
  init(_ payload: Data) throws {
    guard let object = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any] else {
      throw FoundationStorageError.invalidFixture
    }
    values = object
  }
  func string(_ key: String) throws -> String {
    guard let value = values[key] as? String else { throw FoundationStorageError.invalidFixture }
    return value
  }
  func optionalString(_ key: String) throws -> String? {
    values[key] is NSNull ? nil : try string(key)
  }
  func number(_ key: String) throws -> Double {
    guard let value = values[key] as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
      value.doubleValue.isFinite
    else {
      throw FoundationStorageError.invalidFixture
    }
    return value.doubleValue
  }
  func numericText(_ key: String) throws -> String {
    _ = try number(key)
    return (values[key] as! NSNumber).stringValue
  }
  func integer(_ key: String) throws -> Int64 {
    guard let n = values[key] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else {
      throw FoundationStorageError.invalidFixture
    }
    if let exact = Int64(n.stringValue) { return exact }
    guard let exact = Int64(exactly: n.doubleValue) else {
      throw FoundationStorageError.invalidFixture
    }
    return exact
  }
  func boolean(_ key: String) throws -> Bool {
    guard let n = values[key] as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() else {
      throw FoundationStorageError.invalidFixture
    }
    return n.boolValue
  }
  func ids(_ key: String) throws -> [String] {
    guard let ids = values[key] as? [String], Set(ids).count == ids.count,
      ids.allSatisfy({ UUID(uuidString: $0)?.uuidString == $0 })
    else {
      throw FoundationStorageError.invalidFixture
    }
    return ids
  }
  func photoData() throws -> Data {
    guard let bytes = Data(base64Encoded: try string("imageDataBase64")),
      bytes.base64EncodedString() == (try string("imageDataBase64"))
    else {
      throw FoundationStorageError.invalidFixture
    }
    return bytes
  }
}

private struct ProjectionLink {
  let field: String
  let position: Int
  let entity: String
  let id: String
}

private struct ProjectionInput {
  let rows: [LegacySnapshotRow]
  let snapshotID: String
  let timeZoneID: String
  let referenceDate: Date
  let digest: String
  let warnings: [String]
  var importTimestamp: Int64 { Int64(referenceDate.timeIntervalSince1970 * 1000) }
  var hasSingleUsableHeight: Bool {
    let profiles = rows.filter { $0.entity == "UserProfile" }
    guard profiles.count == 1,
      let inches = try? ProjectionFields(profiles[0].payload).number("heightInInches")
    else { return false }
    return inches > 0 && inches * 2.54 < 300
  }

  private static let layouts: [String: String] = [
    "FoodItem":
      "name calories protein carbs fat servingDescription sourceType isSavedToLibrary menuItem",
    "Restaurant": "name menuItems buildableTemplates",
    "MenuItem": "name calories protein carbs fat category isCustom restaurant modifiers",
    "MenuItemModifier": "name calorieDelta proteinDelta carbDelta fatDelta menuItem",
    "BuildableItemTemplate": "name restaurant categories",
    "BuildComponentCategory": "name selectionType isRequired sortOrder template options",
    "BuildComponentOption": "name calories protein carbs fat supportsDouble category",
    "DiaryEntry":
      "dateReference mealType foodItem quantity note caloriesSnapshot proteinSnapshot carbsSnapshot fatSnapshot",
    "SavedMeal": "name items",
    "SavedMealItem": "quantity foodItem savedMeal",
    "WeightEntry": "dateReference enteredValue enteredUnit weightKG progressEntry",
    "ProgressEntry": "dateReference notes weightEntry photos",
    "ProgressPhoto": "imageDataBase64 sortOrder progressEntry",
    "Note": "dateReference text linkedDiaryEntry",
    "UserProfile":
      "heightInInches startingWeight activityLevel dailyCalorieGoal proteinGoal carbGoal fatGoal",
  ]

  init(_ supplied: [LegacySnapshotRow], snapshotID: String, timeZoneID: String, referenceDate: Date)
    throws
  {
    guard UUID(uuidString: snapshotID) != nil, TimeZone(identifier: timeZoneID) != nil,
      referenceDate.timeIntervalSince1970.isFinite,
      (0...7_258_118_400).contains(referenceDate.timeIntervalSince1970)
    else {
      throw FoundationStorageError.invalidFixture
    }
    let rows = supplied.sorted { ($0.entity, $0.id) < ($1.entity, $1.id) }
    let keys = Set(rows.map { $0.entity + "/" + $0.id })
    guard keys.count == rows.count else { throw FoundationStorageError.invalidFixture }
    var warningSet: Set<String> = [
      "Historical time zones were not stored; local calendar dates use the explicitly supplied \(timeZoneID) assumption.",
      "External food provenance and serving gram weights are unknown. Portion nutrition, diary snapshots, signed modifiers and saved portions use typed compatibility tables; no per-100g values or gram weights are invented.",
      "No cloud sync, Stack store, encryption claim or live database cutover is enabled by this rehearsal.",
    ]
    var values: [String: ProjectionFields] = [:]
    for row in rows {
      guard UUID(uuidString: row.id)?.uuidString == row.id, let layout = Self.layouts[row.entity]
      else {
        throw FoundationStorageError.invalidFixture
      }
      let f = try ProjectionFields(row.payload)
      guard Set(f.values.keys) == Set(layout.split(separator: " ").map(String.init)) else {
        throw FoundationStorageError.invalidFixture
      }
      let links = try Self.relationships(row)
      let refs = links.map { LegacyReference($0.entity, $0.id) }.sorted(by: Self.linkOrder)
      guard refs == row.references.sorted(by: Self.linkOrder),
        refs.allSatisfy({ keys.contains($0.entity + "/" + $0.id) }),
        Set(refs.map { $0.entity + "/" + $0.id }).count == refs.count
      else {
        throw FoundationStorageError.invalidFixture
      }
      try Self.validateValues(row.entity, f)
      let parentFields = [
        "MenuItemModifier": "menuItem", "BuildComponentCategory": "template",
        "BuildComponentOption": "category", "SavedMealItem": "savedMeal",
        "ProgressPhoto": "progressEntry",
      ]
      if let parent = parentFields[row.entity], try f.optionalString(parent) == nil {
        warningSet.insert(
          "Unlinked legacy objects are retained without manufacturing parent records.")
      }
      if row.entity == "DiaryEntry", try f.optionalString("foodItem") == nil {
        warningSet.insert(
          "Diary entries with no linked food retain their stored nutrition snapshots and meal, without inventing a food identity."
        )
      }
      if row.entity == "UserProfile" {
        warningSet.insert(
          "Profile goals, starting weight and activity are retained as typed values. Their original effective date was not stored, so no dated nutrition target or weigh-in is invented."
        )
      }
      if row.entity == "ProgressPhoto" {
        warningSet.insert(
          "Photo bytes and order are preserved locally without modification. Original MIME, dimensions, EXIF stripping and historical biometric access state were not stored; these are not certified or uploaded."
        )
      }
      values[row.entity + "/" + row.id] = f
    }
    try Self.validateInverses(rows, values)
    for macro in ["caloriesSnapshot", "proteinSnapshot", "carbsSnapshot", "fatSnapshot"] {
      let total = try rows.filter { $0.entity == "DiaryEntry" }.reduce(0.0) {
        $0 + (try values["DiaryEntry/" + $1.id]!.number(macro))
      }
      guard total.isFinite else { throw FoundationStorageError.invalidFixture }
    }
    if rows.filter({ $0.entity == "UserProfile" }).count > 1 {
      warningSet.insert(
        "Multiple profiles are retained individually; no profile is chosen to populate the account height."
      )
    }
    self.rows = rows
    self.snapshotID = snapshotID
    self.timeZoneID = timeZoneID
    self.referenceDate = referenceDate
    self.warnings = warningSet.sorted()
    var bytes = Data()
    for row in rows {
      let links = try Self.linkData(row.references)
      for data in [Data(row.entity.utf8), Data(row.id.utf8), row.payload, links] {
        bytes.append(Data("\(data.count):".utf8))
        bytes.append(data)
      }
    }
    digest = Self.hash(bytes)
  }

  func localDay(_ date: Date) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timeZoneID)!
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
  }
  func links(_ row: LegacySnapshotRow) throws -> [ProjectionLink] { try Self.relationships(row) }
  static func linkOrder(_ a: LegacyReference, _ b: LegacyReference) -> Bool {
    (a.entity, a.id) < (b.entity, b.id)
  }
  static func hash(_ bytes: Data) -> String {
    SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
  }
  static func linkData(_ links: [LegacyReference]) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(links.sorted(by: linkOrder))
  }

  static func relationships(_ row: LegacySnapshotRow) throws -> [ProjectionLink] {
    let f = try ProjectionFields(row.payload)
    var result: [ProjectionLink] = []
    func one(_ field: String, _ entity: String) throws {
      if let id = try f.optionalString(field) {
        guard UUID(uuidString: id)?.uuidString == id else {
          throw FoundationStorageError.invalidFixture
        }
        result.append(ProjectionLink(field: field, position: 0, entity: entity, id: id))
      }
    }
    func many(_ field: String, _ entity: String) throws {
      result += try f.ids(field).enumerated().map {
        ProjectionLink(field: field, position: $0.offset, entity: entity, id: $0.element)
      }
    }
    switch row.entity {
    case "FoodItem": try one("menuItem", "MenuItem")
    case "Restaurant":
      try many("menuItems", "MenuItem")
      try many("buildableTemplates", "BuildableItemTemplate")
    case "MenuItem":
      try one("restaurant", "Restaurant")
      try many("modifiers", "MenuItemModifier")
    case "MenuItemModifier": try one("menuItem", "MenuItem")
    case "BuildableItemTemplate":
      try one("restaurant", "Restaurant")
      try many("categories", "BuildComponentCategory")
    case "BuildComponentCategory":
      try one("template", "BuildableItemTemplate")
      try many("options", "BuildComponentOption")
    case "BuildComponentOption": try one("category", "BuildComponentCategory")
    case "DiaryEntry": try one("foodItem", "FoodItem")
    case "SavedMeal": try many("items", "SavedMealItem")
    case "SavedMealItem":
      try one("foodItem", "FoodItem")
      try one("savedMeal", "SavedMeal")
    case "WeightEntry": try one("progressEntry", "ProgressEntry")
    case "ProgressEntry":
      try one("weightEntry", "WeightEntry")
      try many("photos", "ProgressPhoto")
    case "ProgressPhoto": try one("progressEntry", "ProgressEntry")
    case "Note": try one("linkedDiaryEntry", "DiaryEntry")
    case "UserProfile": break
    default: throw FoundationStorageError.invalidFixture
    }
    return result
  }

  private static func validateValues(_ entity: String, _ f: ProjectionFields) throws {
    func numbers(_ fields: String, nonnegative: Bool = true) throws {
      for key in fields.split(separator: " ").map(String.init) {
        let n = try f.number(key)
        guard !nonnegative || n >= 0 else { throw FoundationStorageError.invalidFixture }
      }
    }
    func choice(_ field: String, _ choices: [String]) throws {
      guard choices.contains(try f.string(field)) else {
        throw FoundationStorageError.invalidFixture
      }
    }
    if f.values["name"] != nil { _ = try f.string("name") }
    if f.values["dateReference"] != nil {
      let epoch = try f.number("dateReference") + Date.timeIntervalBetween1970AndReferenceDate
      guard (0...7_258_118_400).contains(epoch) else { throw FoundationStorageError.invalidFixture }
    }
    switch entity {
    case "FoodItem":
      try numbers("calories protein carbs fat")
      _ = try f.string("servingDescription")
      _ = try f.boolean("isSavedToLibrary")
      try choice("sourceType", ["generic", "restaurantMenuItem"])
    case "MenuItem":
      try numbers("calories protein carbs fat")
      _ = try f.boolean("isCustom")
      try choice("category", ["appetizer", "entree", "side", "drink", "dessert"])
    case "MenuItemModifier":
      try numbers("calorieDelta proteinDelta carbDelta fatDelta", nonnegative: false)
    case "BuildComponentCategory":
      try choice("selectionType", ["single", "multiple"])
      _ = try f.integer("sortOrder")
      _ = try f.boolean("isRequired")
    case "BuildComponentOption":
      try numbers("calories protein carbs fat")
      _ = try f.boolean("supportsDouble")
    case "DiaryEntry":
      try numbers("quantity caloriesSnapshot proteinSnapshot carbsSnapshot fatSnapshot")
      try choice("mealType", ["breakfast", "lunch", "dinner", "snack"])
      _ = try f.optionalString("note")
    case "SavedMealItem": try numbers("quantity")
    case "WeightEntry":
      try choice("enteredUnit", ["lb"])
      let lb = try f.number("enteredValue")
      let kg = try f.number("weightKG")
      guard kg > 0, kg < 1000, lb > 0, kg == lb * 0.45359237 else {
        throw FoundationStorageError.invalidFixture
      }
    case "ProgressEntry": _ = try f.string("notes")
    case "ProgressPhoto":
      _ = try f.photoData()
      _ = try f.integer("sortOrder")
    case "Note": _ = try f.string("text")
    case "UserProfile":
      try numbers("heightInInches startingWeight proteinGoal carbGoal fatGoal")
      _ = try f.integer("dailyCalorieGoal")
      try choice(
        "activityLevel",
        ["sedentary", "lightlyActive", "moderatelyActive", "veryActive", "extraActive"])
    default: break
    }
  }

  private static func validateInverses(
    _ rows: [LegacySnapshotRow], _ values: [String: ProjectionFields]
  ) throws {
    // Parent arrays and child backlinks must agree; a null parent is a legitimate orphan.
    let pairs = [
      ("Restaurant", "menuItems", "MenuItem", "restaurant"),
      ("Restaurant", "buildableTemplates", "BuildableItemTemplate", "restaurant"),
      ("MenuItem", "modifiers", "MenuItemModifier", "menuItem"),
      ("BuildableItemTemplate", "categories", "BuildComponentCategory", "template"),
      ("BuildComponentCategory", "options", "BuildComponentOption", "category"),
      ("SavedMeal", "items", "SavedMealItem", "savedMeal"),
      ("ProgressEntry", "photos", "ProgressPhoto", "progressEntry"),
    ]
    for (parent, array, child, back) in pairs {
      for row in rows where row.entity == parent {
        for id in try values[parent + "/" + row.id]!.ids(array) {
          guard try values[child + "/" + id]!.optionalString(back) == row.id else {
            throw FoundationStorageError.invalidFixture
          }
        }
      }
      for row in rows where row.entity == child {
        if let id = try values[child + "/" + row.id]!.optionalString(back) {
          guard try values[parent + "/" + id]!.ids(array).contains(row.id) else {
            throw FoundationStorageError.invalidFixture
          }
        }
      }
    }
    for row in rows where row.entity == "ProgressEntry" {
      let f = values["ProgressEntry/" + row.id]!
      let photos = try f.ids("photos")
      let sorted = try photos.map { ($0, try values["ProgressPhoto/" + $0]!.integer("sortOrder")) }
        .sorted { ($0.1, $0.0) < ($1.1, $1.0) }.map(\.0)
      guard photos == sorted else { throw FoundationStorageError.invalidFixture }
      if let weight = try f.optionalString("weightEntry") {
        guard try values["WeightEntry/" + weight]!.optionalString("progressEntry") == row.id else {
          throw FoundationStorageError.invalidFixture
        }
      }
    }
    for row in rows where row.entity == "WeightEntry" {
      if let progress = try values["WeightEntry/" + row.id]!.optionalString("progressEntry") {
        guard try values["ProgressEntry/" + progress]!.optionalString("weightEntry") == row.id
        else { throw FoundationStorageError.invalidFixture }
      }
    }
  }
}
