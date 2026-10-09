import CaliberCore
import CryptoKit
import Foundation
import GRDB

public struct LegacyReference: Codable, Equatable, Sendable {
  public let entity: String
  public let id: String
  public init(_ entity: String, _ id: String) {
    self.entity = entity
    self.id = id
  }
}
public struct LegacySnapshotRow: Codable, Equatable, Sendable {
  public let entity: String
  public let id: String
  public let payload: Data
  public let references: [LegacyReference]
  public init(entity: String, id: String, payload: Data, references: [LegacyReference]) {
    self.entity = entity
    self.id = id
    self.payload = payload
    self.references = references
  }
}
/// A lossless rehearsal snapshot, not a live cutover. Uses supported SwiftData values supplied by the adapter.
public actor LegacyShadowArchive {
  private let queue: DatabaseQueue
  public init(directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var location = directory
    var options = URLResourceValues()
    options.isExcludedFromBackup = true
    try location.setResourceValues(options)
    #if os(iOS)
      try FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
    #endif
    queue = try DatabaseQueue(
      path: directory.appendingPathComponent("legacy-rehearsal.sqlite").path)
    var migrator = DatabaseMigrator()
    migrator.registerMigration("lossless-copy-v1") { db in
      try db.execute(
        sql: """
          CREATE TABLE snapshots(id TEXT PRIMARY KEY,created_at REAL NOT NULL,source_version INTEGER NOT NULL CHECK(source_version=1),row_count INTEGER NOT NULL) STRICT;
          CREATE TABLE legacy_map(entity TEXT NOT NULL,legacy_id TEXT NOT NULL,target_id TEXT NOT NULL UNIQUE,PRIMARY KEY(entity,legacy_id)) STRICT;
          CREATE TABLE snapshot_rows(snapshot_id TEXT NOT NULL REFERENCES snapshots(id),entity TEXT NOT NULL,legacy_id TEXT NOT NULL,payload BLOB NOT NULL,sha256 TEXT NOT NULL,links BLOB NOT NULL,PRIMARY KEY(snapshot_id,entity,legacy_id)) STRICT;
          """)
    }
    try migrator.migrate(queue)
  }
  public func copy(_ rows: [LegacySnapshotRow], failAfter: Int? = nil) throws -> String {
    let keys = Set(rows.map { $0.entity + "/" + $0.id })
    guard keys.count == rows.count,
      rows.allSatisfy({ row in
        UUID(uuidString: row.id) != nil
          && (try? JSONSerialization.jsonObject(with: row.payload)) is [String: Any]
          && row.references.allSatisfy { keys.contains($0.entity + "/" + $0.id) }
      })
    else { throw FoundationStorageError.invalidFixture }
    let id = UUIDv7.make()
    try queue.write { db in
      try db.execute(
        sql: "INSERT INTO snapshots VALUES (?,?,1,?)",
        arguments: [id, Date().timeIntervalSince1970, rows.count])
      for (index, row) in rows.enumerated() {
        if failAfter == index { throw FoundationStorageError.unavailable }
        try db.execute(
          sql: "INSERT OR IGNORE INTO legacy_map VALUES (?,?,?)",
          arguments: [row.entity, row.id, UUIDv7.make()])
        let links = try JSONEncoder().encode(row.references)
        try db.execute(
          sql: "INSERT INTO snapshot_rows VALUES (?,?,?,?,?,?)",
          arguments: [id, row.entity, row.id, row.payload, Self.digest(row.payload), links])
      }
    }
    // Re-read stored bytes and references before reporting a successful copy.
    guard try read(snapshotID: id) == rows.sorted(by: Self.order) else {
      throw FoundationStorageError.incompleteFixture
    }
    return id
  }
  public func read(snapshotID: String) throws -> [LegacySnapshotRow] {
    try queue.read { db in
      guard
        let count = try Int.fetchOne(
          db, sql: "SELECT row_count FROM snapshots WHERE id=?", arguments: [snapshotID])
      else { throw FoundationStorageError.incompleteFixture }
      let rows = try Row.fetchAll(
        db, sql: "SELECT * FROM snapshot_rows WHERE snapshot_id=? ORDER BY entity,legacy_id",
        arguments: [snapshotID])
      guard rows.count == count else { throw FoundationStorageError.incompleteFixture }
      return try rows.map { row in
        let payload: Data = row["payload"]
        guard Self.digest(payload) == row["sha256"] as String else {
          throw FoundationStorageError.incompleteFixture
        }
        let links: Data = row["links"]
        return LegacySnapshotRow(
          entity: row["entity"], id: row["legacy_id"], payload: payload,
          references: try JSONDecoder().decode([LegacyReference].self, from: links))
      }
    }
  }
  public func mappedID(entity: String, legacyID: String) throws -> String? {
    try queue.read {
      try String.fetchOne(
        $0, sql: "SELECT target_id FROM legacy_map WHERE entity=? AND legacy_id=?",
        arguments: [entity, legacyID])
    }
  }
  public func snapshotCount() throws -> Int {
    try queue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM snapshots") ?? 0 }
  }
  private static func order(_ a: LegacySnapshotRow, _ b: LegacySnapshotRow) -> Bool {
    (a.entity, a.id) < (b.entity, b.id)
  }
  private static func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}
