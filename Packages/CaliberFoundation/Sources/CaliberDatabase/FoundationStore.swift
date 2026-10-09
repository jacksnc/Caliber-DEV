import CaliberCore
import Foundation
import GRDB

public struct FoundationStorageSummary: Equatable, Sendable {
  public let foodLogs: Int
  public let weighIns: Int
  public let workouts: Int
  public let sets: Int
  public let programs: Int
  public let simulationEvents: Int
  public let migrationVersion: Int
}

/// Synthetic demo storage only. Separate files are a boundary, not an encryption claim.
/// Private Stack capture remains disabled until the separate security release gates pass.
public actor FoundationStore {
  private let core: DatabaseQueue
  private let stack: DatabaseQueue
  private static let account = "018f0000-0000-7000-8000-000000000001"
  private static let device = "018f0000-0000-7000-8000-000000000002"

  public init(directory: URL) throws {
    do {
      core = try DatabaseSchema.open(directory: directory, domain: .core)
      stack = try DatabaseSchema.open(directory: directory, domain: .stack)
    } catch { throw FoundationStorageError.unavailable }
  }

  public func prepareDemo(_ dataset: DemoDataset) throws {
    try Self.validate(dataset)
    do {
      // The manifest never contains Stack payloads. Both stores have their own resumable checkpoint.
      let coreFixture = DemoDataset(
        version: dataset.version, seed: dataset.seed, timeZoneID: dataset.timeZoneID,
        days: dataset.days, simulation: [])
      let coreJSON = try Self.json(coreFixture)
      try core.write { db in
        if let prior = try String.fetchOne(
          db, sql: "SELECT fixture_json FROM foundation_demo_manifest")
        {
          guard prior == coreJSON else { throw FoundationStorageError.differentFixture }
          return
        }
        try Self.seedCore(db, dataset: dataset)
        try insert(
          db, "foundation_demo_manifest",
          [
            "singleton": 1, "version": dataset.version, "seed": String(dataset.seed),
            "timezone": dataset.timeZoneID, "status": "core_ready", "fixture_json": coreJSON,
          ])
      }
      let stackJSON = try Self.json(dataset.simulation)
      try stack.write { db in
        if let prior = try String.fetchOne(
          db, sql: "SELECT fixture_json FROM foundation_demo_manifest")
        {
          guard prior == stackJSON else { throw FoundationStorageError.differentFixture }
          return
        }
        try Self.seedStack(db, dataset: dataset)
        try insert(
          db, "foundation_demo_manifest",
          [
            "singleton": 1, "version": dataset.version, "seed": String(dataset.seed),
            "timezone": dataset.timeZoneID, "status": "complete", "fixture_json": stackJSON,
          ])
      }
      try core.write { db in
        try db.execute(
          sql: "UPDATE foundation_demo_manifest SET status='complete' WHERE singleton=1")
      }
    } catch let error as FoundationStorageError { throw error } catch {
      throw FoundationStorageError.unavailable
    }
  }

  public func loadDemo() throws -> DemoDataset? {
    do {
      guard
        let coreJSON = try core.read({ db in
          try String.fetchOne(
            db, sql: "SELECT fixture_json FROM foundation_demo_manifest WHERE status='complete'")
        })
      else { return nil }
      let base = try JSONDecoder().decode(DemoDataset.self, from: Data(coreJSON.utf8))
      let simulation = try stack.read { db -> [DemoSimulationEvent] in
        guard
          let manifest = try Row.fetchOne(
            db, sql: "SELECT seed,version FROM foundation_demo_manifest WHERE status='complete'"),
          manifest["seed"] as String == String(base.seed),
          manifest["version"] as Int == base.version
        else {
          throw FoundationStorageError.incompleteFixture
        }
        return try String.fetchAll(db, sql: "SELECT notes FROM events ORDER BY occurred_at,id").map
        {
          try JSONDecoder().decode(DemoSimulationEvent.self, from: Data($0.utf8))
        }
      }
      // Core observations come from normalized domain tables, not the fixture manifest.
      let days = try core.read { db in
        try Row.fetchAll(
          db,
          sql: """
            SELECT d.*, f.calories_kcal AS actual_calories, f.protein_g AS actual_protein,
                w.weight_kg AS actual_weight,
                (SELECT SUM(r.load_kg*r.reps) FROM workouts wo JOIN workout_exercises we ON we.workout_id=wo.id
                 JOIN workout_sets ws ON ws.workout_exercise_id=we.id JOIN set_revisions r ON r.id=ws.current_revision_id
                 WHERE wo.local_date=d.local_date) AS actual_volume,
                (SELECT COUNT(*) FROM workouts wo JOIN workout_exercises we ON we.workout_id=wo.id
                 JOIN workout_sets ws ON ws.workout_exercise_id=we.id WHERE wo.local_date=d.local_date) AS actual_sets
            FROM foundation_demo_days d LEFT JOIN food_logs f ON f.local_date=d.local_date
            LEFT JOIN weigh_ins w ON w.local_date=d.local_date ORDER BY d.local_date
            """
        ).map { row in
          DemoDay(
            localDate: row["local_date"], date: Date(timeIntervalSince1970: row["occurred_at"]),
            calories: row["actual_calories"], protein: row["actual_protein"],
            weightKG: row["actual_weight"],
            trainingVolumeKG: row["volume_kg"] as Double? == nil ? nil : row["actual_volume"],
            trainingSets: row["set_count"] as Int? == nil ? nil : row["actual_sets"],
            isDeload: row["is_deload"], phase: row["phase"])
        }
      }
      return DemoDataset(
        version: base.version, seed: base.seed, timeZoneID: base.timeZoneID, days: days,
        simulation: simulation)
    } catch let error as FoundationStorageError { throw error } catch {
      throw FoundationStorageError.unavailable
    }
  }

  public func storageSummary() throws -> FoundationStorageSummary {
    do {
      let counts = try core.read { db in
        try ["food_logs", "weigh_ins", "workouts", "workout_sets", "programs"].map { table in
          try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)") ?? 0
        }
      }
      let events = try stack.read { db in
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM events") ?? 0
      }
      return FoundationStorageSummary(
        foodLogs: counts[0], weighIns: counts[1], workouts: counts[2], sets: counts[3],
        programs: counts[4], simulationEvents: events, migrationVersion: 2)
    } catch { throw FoundationStorageError.unavailable }
  }

  private static func json<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }
  private static func validate(_ dataset: DemoDataset) throws {
    guard dataset.version > 0, TimeZone(identifier: dataset.timeZoneID) != nil,
      Set(dataset.days.map(\.localDate)).count == dataset.days.count,
      Set(dataset.simulation.map(\.id)).count == dataset.simulation.count
    else { throw FoundationStorageError.invalidFixture }
    for day in dataset.days {
      let values = [day.calories, day.protein, day.weightKG, day.trainingVolumeKG].compactMap { $0 }
      guard values.allSatisfy({ $0.isFinite && $0 >= 0 }),
        (day.calories == nil) == (day.protein == nil),
        (day.trainingVolumeKG == nil) == (day.trainingSets == nil),
        day.trainingSets.map({ $0 > 0 }) ?? true,
        day.date.timeIntervalSince1970.isFinite,
        (0...7_258_118_400).contains(day.date.timeIntervalSince1970)
      else { throw FoundationStorageError.invalidFixture }
    }
    guard
      dataset.simulation.allSatisfy({ event in
        event.level.isFinite && event.level >= 0 && event.date.timeIntervalSince1970.isFinite
          && (0...7_258_118_400).contains(event.date.timeIntervalSince1970)
          && dataset.days.contains(where: { $0.localDate == event.localDate })
      })
    else { throw FoundationStorageError.invalidFixture }
  }

  private static func common(_ id: String = databaseUUID(), timestamp: Int64 = 0) -> [String: (
    any DatabaseValueConvertible
  )?] {
    [
      "id": id, "account_id": account, "created_at": timestamp, "updated_at": timestamp,
      "source": "import",
    ]
  }
  private static func add(
    _ db: Database, _ table: String, _ fields: [String: (any DatabaseValueConvertible)?],
    id: String = databaseUUID(), timestamp: Int64 = 0
  ) throws {
    try insert(db, table, common(id, timestamp: timestamp).merging(fields) { _, new in new })
  }
  private static func seedIdentity(_ db: Database) throws {
    // Both account and context are created in one transaction. Defer the FK until commit
    // so the import context suppresses even the synthetic account's first outbox record.
    try db.execute(sql: "PRAGMA defer_foreign_keys = ON")
    try add(db, "sync_context", ["mode": "remote_apply"])
    try insert(
      db, "accounts", ["id": account, "created_at": 0, "updated_at": 0, "source": "import"])
    try add(db, "devices", ["label": "Synthetic fixture", "platform": "demo"], id: device)
  }

  static func seedCore(_ db: Database, dataset: DemoDataset) throws {
    try seedIdentity(db)
    let source = databaseUUID()
    let food = databaseUUID()
    let slot = databaseUUID()
    let exercise = databaseUUID()
    let setType = databaseUUID()
    try add(
      db, "food_sources",
      [
        "source_kind": "user", "name": "Caliber generated fixture", "license_identifier": "CC0-1.0",
        "attribution": "Synthetic values; no restaurant or clinical dataset",
      ], id: source)
    try add(
      db, "foods",
      [
        "name": "Synthetic daily food total", "normalized_name": "synthetic daily food total",
        "source_id": source, "quality_rank": 0, "is_custom": 1,
      ], id: food)
    try add(db, "meal_slots", ["name": "Demo daily total", "position": 0], id: slot)
    try add(
      db, "exercises",
      [
        "name": "Synthetic training movement", "normalized_name": "synthetic training movement",
        "movement_pattern": "demo", "mechanics": "other", "metric_type": "weight_reps",
        "is_custom": 1,
      ], id: exercise)
    try add(
      db, "set_types",
      [
        "name": "Synthetic working set", "glyph": "circle", "color_token": "train",
        "counts_volume": 1, "counts_hard_sets": 1, "counts_pr": 1,
      ], id: setType)
    var programs: [String: String] = [:]
    for phase in Set(dataset.days.map(\.phase)).sorted() {
      let program = databaseUUID()
      programs[phase] = program
      try add(
        db, "programs",
        ["name": "Demo: " + phase, "notes": "Synthetic timeline phase; not a prescribed program"],
        id: program)
    }
    for (index, day) in dataset.days.enumerated() {
      let timestamp = Int64(day.date.timeIntervalSince1970 * 1000)
      let timed: [String: (any DatabaseValueConvertible)?] = [
        "occurred_at": timestamp, "tz": dataset.timeZoneID, "local_date": day.localDate,
      ]
      try insert(
        db, "foundation_demo_days",
        [
          "local_date": day.localDate, "occurred_at": day.date.timeIntervalSince1970,
          "phase": day.phase, "is_deload": day.isDeload, "calories": day.calories,
          "protein": day.protein, "weight_kg": day.weightKG, "volume_kg": day.trainingVolumeKG,
          "set_count": day.trainingSets,
        ])
      if let calories = day.calories, let protein = day.protein {
        let meal = databaseUUID()
        try add(
          db, "meal_logs",
          timed.merging(["meal_slot_id": slot, "state": "eaten"]) { _, new in new }, id: meal,
          timestamp: timestamp)
        try add(
          db, "food_logs",
          timed.merging([
            "meal_log_id": meal, "food_id": food, "food_name": "Synthetic daily total",
            "grams": 100, "entered_value": "1", "entered_unit": "demo day",
            "calories_kcal": calories, "protein_g": protein,
            "carbs_g": (calories - protein * 4 - 70 * 9) / 4, "fat_g": 70,
            "confirmed_at": timestamp,
          ]) { _, new in new }, timestamp: timestamp)
        try add(
          db, "nutrition_days",
          ["local_date": day.localDate, "status": "complete", "confirmed_at": timestamp],
          timestamp: timestamp)
      }
      if let weight = day.weightKG {
        try add(
          db, "weigh_ins",
          timed.merging([
            "weight_kg": weight, "entered_value": String(weight), "entered_unit": "kg",
          ]) { _, new in new }, timestamp: timestamp)
      }
      if let volume = day.trainingVolumeKG, let sets = day.trainingSets {
        let programDay = databaseUUID()
        let workout = databaseUUID()
        let workoutExercise = databaseUUID()
        try add(
          db, "program_days",
          [
            "program_id": programs[day.phase], "week_number": index / 7 + 1,
            "day_number": index % 7 + 1, "position": index,
            "name": day.isDeload ? "Synthetic deload" : "Synthetic session",
          ], id: programDay, timestamp: timestamp)
        try add(
          db, "workouts",
          timed.merging([
            "status": "finished", "ended_at": timestamp + 3_600_000, "program_day_id": programDay,
            "start_origin": "program",
          ]) { _, new in new }, id: workout, timestamp: timestamp)
        try add(
          db, "workout_exercises", ["workout_id": workout, "exercise_id": exercise, "position": 0],
          id: workoutExercise, timestamp: timestamp)
        for position in 0..<sets {
          let set = databaseUUID()
          let revision = databaseUUID()
          try add(
            db, "workout_sets", ["workout_exercise_id": workoutExercise, "position": position],
            id: set, timestamp: timestamp)
          try add(
            db, "set_revisions",
            timed.merging([
              "set_id": set, "writer_device_id": device, "action": "upsert", "completed": 1,
              "set_type_id": setType, "load_kg": volume / Double(sets) / 10,
              "entered_load_value": String(volume / Double(sets) / 10), "entered_load_unit": "kg",
              "reps": 10,
            ]) { _, new in new }, id: revision, timestamp: timestamp)
          try db.execute(
            sql:
              "UPDATE workout_sets SET current_revision_id=?,logical_clock=logical_clock+1 WHERE id=?",
            arguments: [revision, set])
        }
      }
    }
    try db.execute(
      sql: "UPDATE sync_context SET mode='local',logical_clock=logical_clock+1 WHERE account_id=?",
      arguments: [account])
  }

  static func seedStack(_ db: Database, dataset: DemoDataset) throws {
    try seedIdentity(db)
    let eventType = databaseUUID()
    try add(
      db, "event_registry",
      [
        "event_key": "demo.simulation", "domain": "stack", "label_key": "Synthetic marker",
        "shape_token": "diamond", "color_token": "stack", "source_query_key": "demo.only",
      ], id: eventType)
    for event in dataset.simulation {
      let timestamp = Int64(event.date.timeIntervalSince1970 * 1000)
      try add(
        db, "events",
        [
          "occurred_at": timestamp, "tz": dataset.timeZoneID, "local_date": event.localDate,
          "event_type_id": eventType, "title": "Fictional simulation marker",
          "notes": try json(event),
        ], timestamp: timestamp)
    }
    try db.execute(
      sql: "UPDATE sync_context SET mode='local',logical_clock=logical_clock+1 WHERE account_id=?",
      arguments: [account])
  }
}
