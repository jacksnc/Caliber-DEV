import Foundation
import GRDB

/// Error codes intentionally exclude SQL arguments and health values.
public enum FoundationStorageError: Error, Equatable, Sendable {
  case unavailable, invalidFixture, differentFixture, incompleteFixture, wrongOwner
  case invalidOperation, operationCollision, unresolvedConflict, invalidCursor, transportRejected
}

enum StoreDomain: String, Sendable { case core, stack }

/// Only opens the explicitly supplied new store. It never discovers or opens SwiftData files.
enum DatabaseSchema {
  static func open(directory: URL, domain: StoreDomain, through version: Int = 3) throws
    -> DatabaseQueue
  {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var configuration = Configuration()
    configuration.prepareDatabase { db in
      try db.execute(
        sql: "PRAGMA foreign_keys = ON; PRAGMA recursive_triggers = ON; PRAGMA synchronous = FULL")
    }
    let queue = try DatabaseQueue(
      path: directory.appendingPathComponent(domain.rawValue + ".sqlite").path,
      configuration: configuration)
    try migrate(queue, domain: domain, through: version)
    return queue
  }

  static func migrator(domain: StoreDomain, through version: Int = 3) throws -> DatabaseMigrator {
    guard let url = Bundle.module.url(forResource: domain.rawValue + "_v1", withExtension: "sql")
    else {
      throw FoundationStorageError.unavailable
    }
    let schema = try String(contentsOf: url, encoding: .utf8)
    var migrator = DatabaseMigrator()
    migrator.registerMigration("v1_" + domain.rawValue) { db in try db.execute(sql: schema) }
    if version >= 2 {
      migrator.registerMigration("v2_foundation") { db in
        try db.execute(
          sql: """
            CREATE TABLE foundation_demo_manifest (
                singleton INTEGER PRIMARY KEY CHECK(singleton=1), version INTEGER NOT NULL,
                seed TEXT NOT NULL, timezone TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('core_ready','complete')),
                fixture_json TEXT NOT NULL CHECK(json_valid(fixture_json))
            ) STRICT;
            CREATE TABLE foundation_demo_days (
                local_date TEXT PRIMARY KEY, occurred_at REAL NOT NULL, phase TEXT NOT NULL,
                is_deload INTEGER NOT NULL CHECK(is_deload IN (0,1)),
                calories REAL, protein REAL, weight_kg REAL, volume_kg REAL, set_count INTEGER
            ) STRICT;
            CREATE TABLE foundation_revisions (
                operation_id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, entity_id TEXT NOT NULL,
                namespace TEXT NOT NULL CHECK(namespace IN ('note','weight','food','set')),
                base_revision TEXT, device_id TEXT NOT NULL, logical_clock INTEGER NOT NULL CHECK(logical_clock>=0),
                tombstone INTEGER NOT NULL CHECK(tombstone IN (0,1)), payload BLOB NOT NULL,
                envelope BLOB NOT NULL, acknowledged INTEGER NOT NULL DEFAULT 0 CHECK(acknowledged IN (0,1)),
                outbound INTEGER NOT NULL CHECK(outbound IN (0,1)), server_cursor INTEGER,
                UNIQUE(owner_id,operation_id)
            ) STRICT;
            CREATE INDEX foundation_pending ON foundation_revisions(owner_id,acknowledged,outbound);
            CREATE TABLE foundation_heads (
                owner_id TEXT NOT NULL, entity_id TEXT NOT NULL, namespace TEXT NOT NULL,
                revision_id TEXT, conflicted INTEGER NOT NULL DEFAULT 0 CHECK(conflicted IN (0,1)),
                PRIMARY KEY(owner_id,entity_id,namespace)
            ) STRICT;
            CREATE TABLE foundation_cursors (owner_id TEXT PRIMARY KEY, cursor INTEGER NOT NULL CHECK(cursor>=0)) STRICT;
            CREATE TABLE foundation_owner_mapping (owner_id TEXT PRIMARY KEY, authenticated_subject TEXT NOT NULL UNIQUE) STRICT;
            CREATE TRIGGER foundation_revision_immutable BEFORE UPDATE OF operation_id,owner_id,entity_id,namespace,base_revision,device_id,logical_clock,tombstone,payload,envelope,outbound ON foundation_revisions
            BEGIN SELECT RAISE(ABORT,'immutable_revision'); END;
            CREATE TRIGGER foundation_revision_no_delete BEFORE DELETE ON foundation_revisions
            BEGIN SELECT RAISE(ABORT,'immutable_revision'); END;
            """)
      }
    }
    if version >= 3 {
      migrator.registerMigration("v3_journal_indexes") { db in
        try db.execute(
          sql: """
            CREATE INDEX foundation_entity_history ON foundation_revisions(owner_id,entity_id,namespace,logical_clock,operation_id);
            CREATE INDEX foundation_ack_cursor ON foundation_revisions(owner_id,server_cursor) WHERE server_cursor IS NOT NULL;
            """)
      }
    }
    return migrator
  }

  static func migrate(_ queue: DatabaseQueue, domain: StoreDomain, through version: Int = 3) throws
  {
    try migrator(domain: domain, through: version).migrate(queue)
  }
}

/// UUIDv7 identifiers for local records; server sequence cursors, not these clocks, order sync.
func databaseUUID() -> String {
  var bytes = withUnsafeBytes(of: UUID().uuid) { Array($0) }
  let milliseconds = UInt64(max(0, Date().timeIntervalSince1970 * 1000))
  for index in 0..<6 { bytes[index] = UInt8(truncatingIfNeeded: milliseconds >> ((5 - index) * 8)) }
  bytes[6] = 0x70 | (bytes[6] & 0x0f)
  bytes[8] = 0x80 | (bytes[8] & 0x3f)
  let hex = bytes.map { String(format: "%02x", $0) }.joined()
  return
    "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20))"
}

func insert(_ db: Database, _ table: String, _ values: [String: (any DatabaseValueConvertible)?])
  throws
{
  // Table/column identifiers are exclusively literals owned by this module, never remote input.
  let keys = values.keys.sorted()
  let placeholders = Array(repeating: "?", count: keys.count).joined(separator: ",")
  try db.execute(
    sql: "INSERT INTO \(table) (\(keys.joined(separator: ","))) VALUES (\(placeholders))",
    arguments: StatementArguments(keys.map { values[$0] ?? nil }))
}
