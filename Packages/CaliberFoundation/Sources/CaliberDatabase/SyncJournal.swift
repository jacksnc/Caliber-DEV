import CaliberCore
import Foundation
import GRDB

public enum SyncNamespace: String, Codable, Sendable { case note, weight, food, set }
public struct SyncOperation: Codable, Equatable, Sendable {
  public let operationID: String
  public let ownerID: String
  public let entityID: String
  public let namespace: SyncNamespace
  public let baseRevision: String?
  public let deviceID: String
  public let logicalClock: Int64
  public let tombstone: Bool
  public let payload: Data
  public let resolves: [String]
  public init(
    operationID: String = UUIDv7.make(), ownerID: String, entityID: String,
    namespace: SyncNamespace, baseRevision: String? = nil, deviceID: String, logicalClock: Int64,
    tombstone: Bool = false, payload: Data, resolves: [String] = []
  ) {
    self.operationID = operationID
    self.ownerID = ownerID
    self.entityID = entityID
    self.namespace = namespace
    self.baseRevision = baseRevision
    self.deviceID = deviceID
    self.logicalClock = logicalClock
    self.tombstone = tombstone
    self.payload = payload
    self.resolves = resolves
  }
}
public struct SyncAcknowledgement: Codable, Sendable {
  public let operationID: String
  public let cursor: Int64
  public init(operationID: String, cursor: Int64) {
    self.operationID = operationID
    self.cursor = cursor
  }
}
public struct SyncDelta: Codable, Sendable {
  public let cursor: Int64
  public let operation: SyncOperation
  public init(cursor: Int64, operation: SyncOperation) {
    self.cursor = cursor
    self.operation = operation
  }
}
public struct SyncPage: Codable, Sendable {
  public let ownerID: String
  public let cursor: Int64
  public let changes: [SyncDelta]
  public let hasMore: Bool
  public init(ownerID: String, cursor: Int64, changes: [SyncDelta], hasMore: Bool = false) {
    self.ownerID = ownerID
    self.cursor = cursor
    self.changes = changes
    self.hasMore = hasMore
  }
}
public protocol SyncTransport: Sendable {
  func push(_ operations: [SyncOperation], ownerID: String) async throws -> [SyncAcknowledgement]
  func pull(ownerID: String, after: Int64, limit: Int) async throws -> SyncPage
}
public struct SyncProjection: Equatable, Sendable {
  public let current: SyncOperation?
  public let candidates: [SyncOperation]
  public var isConflicted: Bool { candidates.count > 1 }
}

/// Durable operation journal. Separate from SwiftData until the verified migration cutover.
/// No last-write-wins: divergent leaves remain candidates until an explicit resolution consumes them.
public actor SyncJournal {
  // Gateway/Postgres JSON passes through JavaScript. Integers above this value lose identity.
  private static let maximumExactInteger: Int64 = 9_007_199_254_740_991
  private let db: DatabaseQueue
  public let ownerID: String
  public init(directory: URL, ownerID: String) throws {
    guard UUIDv7.isValid(ownerID) else { throw FoundationStorageError.wrongOwner }
    self.ownerID = ownerID
    db = try DatabaseSchema.open(directory: directory, domain: .core)
  }
  public func bind(authenticatedSubject: String) throws {
    guard UUID(uuidString: authenticatedSubject) != nil else {
      throw FoundationStorageError.wrongOwner
    }
    try db.write { db in
      if let prior = try String.fetchOne(
        db, sql: "SELECT authenticated_subject FROM foundation_owner_mapping WHERE owner_id=?",
        arguments: [ownerID])
      {
        guard prior == authenticatedSubject else { throw FoundationStorageError.wrongOwner }
      } else {
        try db.execute(
          sql: "INSERT INTO foundation_owner_mapping VALUES (?,?)",
          arguments: [ownerID, authenticatedSubject])
      }
    }
  }
  public func enqueue(_ operation: SyncOperation) throws {
    try db.write { db in
      try Self.insert(operation, db: db, owner: ownerID, outbound: true, cursor: nil)
    }
  }
  public func pending(limit: Int = 100) throws -> [SyncOperation] {
    try db.read { db in
      try Data.fetchAll(
        db,
        sql:
          "SELECT envelope FROM foundation_revisions WHERE owner_id=? AND outbound=1 AND acknowledged=0 ORDER BY rowid LIMIT ?",
        arguments: [ownerID, max(1, min(limit, 100))]
      ).map { try JSONDecoder().decode(SyncOperation.self, from: $0) }
    }
  }
  public func cursor() throws -> Int64 {
    try db.read {
      try Int64.fetchOne(
        $0, sql: "SELECT cursor FROM foundation_cursors WHERE owner_id=?", arguments: [ownerID])
        ?? 0
    }
  }
  public func acknowledge(_ values: [SyncAcknowledgement], sent: [SyncOperation]) throws {
    let expected = Set(sent.map(\.operationID))
    guard sent.count == expected.count, sent.allSatisfy({ $0.ownerID == ownerID }),
      values.count == expected.count, Set(values.map(\.operationID)) == expected,
      Set(values.map(\.cursor)).count == values.count,
      values.allSatisfy({ (1...Self.maximumExactInteger).contains($0.cursor) })
    else { throw FoundationStorageError.transportRejected }
    try db.write { db in
      for value in values {
        guard
          let prior = try Row.fetchOne(
            db,
            sql:
              "SELECT envelope,server_cursor FROM foundation_revisions WHERE owner_id=? AND operation_id=? AND outbound=1",
            arguments: [ownerID, value.operationID]),
          let sentOperation = sent.first(where: { $0.operationID == value.operationID }),
          try JSONDecoder().decode(SyncOperation.self, from: prior["envelope"]) == sentOperation
        else { throw FoundationStorageError.transportRejected }
        if let priorCursor: Int64 = prior["server_cursor"], priorCursor != value.cursor {
          throw FoundationStorageError.invalidCursor
        }
        try Self.validateCursor(
          value.cursor, operationID: value.operationID, db: db, owner: ownerID)
        try db.execute(
          sql:
            "UPDATE foundation_revisions SET acknowledged=1,server_cursor=? WHERE owner_id=? AND operation_id=? AND outbound=1",
          arguments: [value.cursor, ownerID, value.operationID])
      }
    }
  }
  public func apply(_ page: SyncPage) throws {
    guard page.ownerID == ownerID, page.changes.count <= 100 else {
      throw FoundationStorageError.wrongOwner
    }
    try db.write { db in
      let prior =
        try Int64.fetchOne(
          db, sql: "SELECT cursor FROM foundation_cursors WHERE owner_id=?", arguments: [ownerID])
        ?? 0
      guard page.cursor >= prior, page.cursor <= Self.maximumExactInteger else {
        throw FoundationStorageError.invalidCursor
      }
      var previous = prior
      for delta in page.changes {
        guard delta.cursor > previous, delta.cursor <= page.cursor else {
          throw FoundationStorageError.invalidCursor
        }
        try Self.insert(
          delta.operation, db: db, owner: ownerID, outbound: false, cursor: delta.cursor)
        previous = delta.cursor
      }
      // A response cannot skip unseen account changes by inventing a high cursor.
      guard page.cursor == previous, !page.hasMore || !page.changes.isEmpty else {
        throw FoundationStorageError.invalidCursor
      }
      try db.execute(
        sql:
          "INSERT INTO foundation_cursors VALUES (?,?) ON CONFLICT(owner_id) DO UPDATE SET cursor=excluded.cursor",
        arguments: [ownerID, page.cursor])
    }
  }
  public func projection(entityID: String, namespace: SyncNamespace) throws -> SyncProjection {
    try db.read {
      try Self.projection(
        Self.operations($0, owner: ownerID, entity: entityID, namespace: namespace))
    }
  }
  private static func operations(
    _ db: Database, owner: String, entity: String, namespace: SyncNamespace
  ) throws -> [SyncOperation] {
    try Data.fetchAll(
      db,
      sql:
        "SELECT envelope FROM foundation_revisions WHERE owner_id=? AND entity_id=? AND namespace=? ORDER BY operation_id",
      arguments: [owner, entity, namespace.rawValue]
    ).map { try JSONDecoder().decode(SyncOperation.self, from: $0) }
  }
  /// A merge revision has several parents: its base plus every explicitly resolved branch.
  /// Walking only baseRevision loses causal history and can choose an older, misleading projection.
  private static func ancestors(of operation: SyncOperation, byID: [String: SyncOperation]) -> Set<
    String
  > {
    var visited = Set<String>()
    var pending = [operation.baseRevision].compactMap { $0 } + operation.resolves
    while let id = pending.popLast() {
      guard visited.insert(id).inserted, let parent = byID[id] else { continue }
      pending.append(contentsOf: [parent.baseRevision].compactMap { $0 } + parent.resolves)
    }
    return visited
  }
  private static func projection(_ operations: [SyncOperation]) -> SyncProjection {
    let consumed = Set(operations.flatMap { [$0.baseRevision].compactMap { $0 } + $0.resolves })
    let leaves = operations.filter { !consumed.contains($0.operationID) }
    if leaves.count <= 1 { return SyncProjection(current: leaves.first, candidates: leaves) }
    let byID = Dictionary(uniqueKeysWithValues: operations.map { ($0.operationID, $0) })
    let paths = leaves.map { ancestors(of: $0, byID: byID) }
    let common = paths.dropFirst().reduce(paths.first ?? []) { $0.intersection($1) }
    // DAGs may have multiple incomparable common ancestors. None is a safe automatic winner.
    let olderAncestors = common.reduce(into: Set<String>()) { result, id in
      if let operation = byID[id] { result.formUnion(ancestors(of: operation, byID: byID)) }
    }
    let nearest = common.subtracting(olderAncestors)
    return SyncProjection(
      current: nearest.count == 1 ? nearest.first.flatMap { byID[$0] } : nil, candidates: leaves)
  }
  private static func validateCursor(
    _ cursor: Int64, operationID: String, db: Database, owner: String
  ) throws {
    guard (1...maximumExactInteger).contains(cursor) else {
      throw FoundationStorageError.invalidCursor
    }
    let existing = try String.fetchOne(
      db,
      sql:
        "SELECT operation_id FROM foundation_revisions WHERE owner_id=? AND server_cursor=? LIMIT 1",
      arguments: [owner, cursor])
    guard existing == nil || existing == operationID else {
      throw FoundationStorageError.invalidCursor
    }
  }
  private static func insert(
    _ op: SyncOperation, db: Database, owner: String, outbound: Bool, cursor: Int64?
  ) throws {
    guard op.ownerID == owner,
      [op.operationID, op.entityID, op.deviceID, owner].allSatisfy(UUIDv7.isValid),
      (0...maximumExactInteger).contains(op.logicalClock), op.payload.count <= 65_536,
      (try? JSONSerialization.jsonObject(with: op.payload)) is [String: Any],
      Set(op.resolves).count == op.resolves.count
    else { throw FoundationStorageError.invalidOperation }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let bytes = try encoder.encode(op)
    if let prior = try Data.fetchOne(
      db, sql: "SELECT envelope FROM foundation_revisions WHERE operation_id=?",
      arguments: [op.operationID])
    {
      guard prior == bytes else { throw FoundationStorageError.operationCollision }
      if let cursor {
        try validateCursor(cursor, operationID: op.operationID, db: db, owner: owner)
        if let existing = try Int64.fetchOne(
          db, sql: "SELECT server_cursor FROM foundation_revisions WHERE operation_id=?",
          arguments: [op.operationID]), existing != cursor
        {
          throw FoundationStorageError.invalidCursor
        }
        // A pulled echo proves server receipt, including a crash before the original ACK.
        try db.execute(
          sql:
            "UPDATE foundation_revisions SET acknowledged=1,server_cursor=? WHERE operation_id=?",
          arguments: [cursor, op.operationID])
      }
      return
    }
    let existing = try operations(db, owner: owner, entity: op.entityID, namespace: op.namespace)
    let parents = ([op.baseRevision].compactMap { $0 } + op.resolves)
    guard
      parents.allSatisfy({ id in
        existing.contains { $0.operationID == id && $0.logicalClock < op.logicalClock }
      })
    else { throw FoundationStorageError.invalidOperation }
    if !op.resolves.isEmpty {
      let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.operationID, $0) })
      let resolved = Set(op.resolves)
      guard resolved.count >= 2 else { throw FoundationStorageError.unresolvedConflict }
      for id in resolved {
        guard let candidate = byID[id] else { throw FoundationStorageError.invalidOperation }
        let ancestors = ancestors(of: candidate, byID: byID)
        guard ancestors.isDisjoint(with: resolved), op.baseRevision.map(ancestors.contains) ?? true
        else { throw FoundationStorageError.unresolvedConflict }
      }
      // New local choices must show every locally known branch. Historical remote choices
      // can precede an offline edit: store both instead of blocking pull or dropping that edit.
      if outbound, Set(projection(existing).candidates.map(\.operationID)) != resolved {
        throw FoundationStorageError.unresolvedConflict
      }
    }
    if let cursor { try validateCursor(cursor, operationID: op.operationID, db: db, owner: owner) }
    try db.execute(
      sql: """
        INSERT INTO foundation_revisions(operation_id,owner_id,entity_id,namespace,base_revision,device_id,logical_clock,tombstone,payload,envelope,acknowledged,outbound,server_cursor)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
        """,
      arguments: [
        op.operationID, owner, op.entityID, op.namespace.rawValue, op.baseRevision, op.deviceID,
        op.logicalClock, op.tombstone, op.payload, bytes, !outbound, outbound, cursor,
      ])
  }
}

public actor SyncEngine {
  private let journal: SyncJournal
  private let transport: any SyncTransport
  private var running = false
  public init(journal: SyncJournal, transport: any SyncTransport) {
    self.journal = journal
    self.transport = transport
  }
  public func synchronize() async throws {
    guard !running else { return }
    running = true
    defer { running = false }
    let owner = journal.ownerID
    // Pull first so concurrent edits become visible before the next upload.
    try await pull(owner)
    var batch = try await journal.pending()
    while !batch.isEmpty {
      let ack = try await transport.push(batch, ownerID: owner)
      try await journal.acknowledge(ack, sent: batch)
      batch = try await journal.pending()
    }
    try await pull(owner)
  }
  private func pull(_ owner: String) async throws {
    var hasMore = true
    while hasMore {
      try Task.checkCancellation()
      let page = try await transport.pull(ownerID: owner, after: journal.cursor(), limit: 100)
      try await journal.apply(page)
      hasMore = page.hasMore
    }
  }
}
