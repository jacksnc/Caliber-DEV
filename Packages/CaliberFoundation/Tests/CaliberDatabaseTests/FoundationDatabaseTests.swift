import CaliberCore
import CaliberSeedData
import Foundation
import GRDB
import Testing

@testable import CaliberDatabase

private func scratch() throws -> URL {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(
    "CaliberTests-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url
}
@Test func demoSurvivesBothMigrationsAndReopenWithoutPrivateLeakage() async throws {
  let directory = try scratch()
  defer { try? FileManager.default.removeItem(at: directory) }
  let old = try DatabaseSchema.open(directory: directory, domain: .core, through: 1)
  let before = try await old.read {
    try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='table'")!
  }
  #expect(before >= 72)
  let dataset = try DemoGenerator.make(yearEnding: Date(timeIntervalSince1970: 1_791_331_200))
  let store = try FoundationStore(directory: directory)
  try await store.prepareDemo(dataset)
  try await store.prepareDemo(dataset)
  let summary = try await store.storageSummary()
  #expect(summary.foodLogs == dataset.days.filter { $0.calories != nil }.count)
  #expect(summary.weighIns == dataset.days.filter { $0.weightKG != nil }.count)
  #expect(summary.workouts == dataset.days.filter { $0.trainingSets != nil }.count)
  #expect(summary.sets == dataset.days.compactMap(\.trainingSets).reduce(0, +))
  #expect(summary.simulationEvents == dataset.simulation.count)
  let reopened = try FoundationStore(directory: directory)
  let restored = try #require(await reopened.loadDemo())
  #expect(restored.days.count == dataset.days.count)
  #expect(restored.simulation == dataset.simulation)
  for (a, b) in zip(restored.days, dataset.days) {
    #expect(a.localDate == b.localDate && a.calories == b.calories && a.weightKG == b.weightKG)
    if let left = a.trainingVolumeKG, let right = b.trainingVolumeKG {
      #expect(abs(left - right) < 1e-7)
    } else {
      #expect(a.trainingVolumeKG == b.trainingVolumeKG)
    }
  }
  let contents = try await old.read {
    try String.fetchOne($0, sql: "SELECT fixture_json FROM foundation_demo_manifest")!
  }
  #expect(!contents.contains("simulation-"))
  #expect(try await old.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM events") } == 0)
  #expect(try await old.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM sync_outbox") } == 0)
}
@Test func differentDemoCannotOverwriteExistingData() async throws {
  let directory = try scratch()
  defer { try? FileManager.default.removeItem(at: directory) }
  let store = try FoundationStore(directory: directory)
  let fixture = try DemoGenerator.make(yearEnding: Date(timeIntervalSince1970: 1_791_331_200))
  try await store.prepareDemo(fixture)
  let other = try DemoGenerator.make(
    yearEnding: Date(timeIntervalSince1970: 1_791_331_200), seed: 9)
  await #expect(throws: FoundationStorageError.differentFixture) {
    try await store.prepareDemo(other)
  }
  #expect(try await store.loadDemo()?.seed == fixture.seed)
}
@Test func migrationFailureRollsBackAndCanRetry() throws {
  let directory = try scratch()
  defer { try? FileManager.default.removeItem(at: directory) }
  let db = try DatabaseSchema.open(directory: directory, domain: .core, through: 1)
  var migrator = try DatabaseSchema.migrator(domain: .core, through: 1)
  migrator.registerMigration("failure-injection") { db in
    try db.execute(
      sql: "CREATE TABLE temporary_failure(id INTEGER); INSERT INTO nonexistent VALUES (1)")
  }
  #expect(throws: (any Error).self) { try migrator.migrate(db) }
  #expect(
    try db.read {
      try Bool.fetchOne(
        $0, sql: "SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE name='temporary_failure')")
    } == false)
  try DatabaseSchema.migrate(db, domain: .core)
}

private let owner = "018f0000-0000-7000-8000-000000000011"
private let device = "018f0000-0000-7000-8000-000000000012"
private let entity = "018f0000-0000-7000-8000-000000000013"
private func operation(
  parent: String? = nil, clock: Int64 = 0, text: String = "fixture", tombstone: Bool = false,
  resolves: [String] = []
) -> SyncOperation {
  SyncOperation(
    ownerID: owner, entityID: entity, namespace: .note, baseRevision: parent, deviceID: device,
    logicalClock: clock, tombstone: tombstone, payload: Data("{\"text\":\"\(text)\"}".utf8),
    resolves: resolves)
}
@Test func durableDivergenceIsVisibleAndResolutionIsExplicit() async throws {
  let directory = try scratch()
  defer { try? FileManager.default.removeItem(at: directory) }
  let journal = try SyncJournal(directory: directory, ownerID: owner)
  let base = operation()
  try await journal.enqueue(base)
  let edit = operation(parent: base.operationID, clock: 1, text: "local")
  try await journal.enqueue(edit)
  try await journal.enqueue(edit)
  let deletion = operation(parent: base.operationID, clock: 2, tombstone: true)
  try await journal.apply(
    SyncPage(ownerID: owner, cursor: 1, changes: [SyncDelta(cursor: 1, operation: deletion)]))
  let conflict = try await journal.projection(entityID: entity, namespace: .note)
  #expect(conflict.isConflicted)
  #expect(conflict.current == base)
  #expect(Set(conflict.candidates.map(\.operationID)) == [edit.operationID, deletion.operationID])
  #expect(try await journal.pending().count == 2)
  let resolution = operation(
    parent: base.operationID, clock: 3, text: "chosen",
    resolves: [edit.operationID, deletion.operationID])
  try await journal.enqueue(resolution)
  let reopened = try SyncJournal(directory: directory, ownerID: owner)
  #expect(try await reopened.projection(entityID: entity, namespace: .note).current == resolution)
  #expect(try await reopened.projection(entityID: entity, namespace: .note).isConflicted == false)
}
@Test func wrongOwnerOrInvalidPageRollsBackAllChangesAndCursor() async throws {
  let directory = try scratch()
  defer { try? FileManager.default.removeItem(at: directory) }
  let journal = try SyncJournal(directory: directory, ownerID: owner)
  let first = operation()
  let second = SyncOperation(
    ownerID: device, entityID: entity, namespace: .note, deviceID: device, logicalClock: 0,
    payload: Data("{}".utf8))
  await #expect(throws: (any Error).self) {
    try await journal.apply(
      SyncPage(
        ownerID: owner, cursor: 2,
        changes: [SyncDelta(cursor: 1, operation: first), SyncDelta(cursor: 2, operation: second)]))
  }
  #expect(try await journal.cursor() == 0)
  #expect(try await journal.projection(entityID: entity, namespace: .note).current == nil)
  await #expect(throws: FoundationStorageError.invalidCursor) {
    try await journal.apply(SyncPage(ownerID: owner, cursor: 99, changes: []))
  }
}
@Test func operationIDReuseAndAccountRebindingAreRejected() async throws {
  let directory = try scratch()
  defer { try? FileManager.default.removeItem(at: directory) }
  let journal = try SyncJournal(directory: directory, ownerID: owner)
  let first = operation()
  try await journal.enqueue(first)
  let altered = SyncOperation(
    operationID: first.operationID, ownerID: owner, entityID: entity, namespace: .note,
    deviceID: device, logicalClock: 0, payload: Data("{}".utf8))
  await #expect(throws: FoundationStorageError.operationCollision) {
    try await journal.enqueue(altered)
  }
  try await journal.bind(authenticatedSubject: "00000000-0000-4000-8000-000000000001")
  await #expect(throws: FoundationStorageError.wrongOwner) {
    try await journal.bind(authenticatedSubject: "00000000-0000-4000-8000-000000000002")
  }
}
private actor LoopbackTransport: SyncTransport {
  var operations: [SyncOperation] = []
  func push(_ input: [SyncOperation], ownerID: String) async throws -> [SyncAcknowledgement] {
    input.map { operation in
      if !operations.contains(where: { $0.operationID == operation.operationID }) {
        operations.append(operation)
      }
      return SyncAcknowledgement(
        operationID: operation.operationID,
        cursor: Int64(
          operations.firstIndex(where: { $0.operationID == operation.operationID })! + 1))
    }
  }
  func pull(ownerID: String, after: Int64, limit: Int) async throws -> SyncPage {
    let values = operations.enumerated().filter { Int64($0.offset + 1) > after }.prefix(limit)
    return SyncPage(
      ownerID: ownerID, cursor: values.last.map { Int64($0.offset + 1) } ?? after,
      changes: values.map { SyncDelta(cursor: Int64($0.offset + 1), operation: $0.element) },
      hasMore: false)
  }
}
@Test func syncRetryDoesNotEchoOrLoseIndependentLogs() async throws {
  let directory = try scratch()
  defer { try? FileManager.default.removeItem(at: directory) }
  let journal = try SyncJournal(directory: directory, ownerID: owner)
  let transport = LoopbackTransport()
  let op = operation()
  try await journal.enqueue(op)
  let engine = SyncEngine(journal: journal, transport: transport)
  try await engine.synchronize()
  try await engine.synchronize()
  #expect(try await journal.pending().isEmpty)
  #expect(try await journal.cursor() == 1)
  #expect(await transport.operations.count == 1)
}

@Test func syntheticFixtureMatchesSQLColumnContract() throws {
  let dir = try scratch()
  defer { try? FileManager.default.removeItem(at: dir) }
  let dataset = try DemoGenerator.make(yearEnding: Date(timeIntervalSince1970: 1_791_331_200))
  let core = try DatabaseSchema.open(directory: dir, domain: .core)
  try core.write { db in try FoundationStore.seedCore(db, dataset: dataset) }
  let stack = try DatabaseSchema.open(directory: dir, domain: .stack)
  try stack.write { db in try FoundationStore.seedStack(db, dataset: dataset) }
}

@Test func historicalRemoteResolutionPreservesNewOfflineBranchAndFindsDAGAncestor() async throws {
  let directory = try scratch()
  defer { try? FileManager.default.removeItem(at: directory) }
  let journal = try SyncJournal(directory: directory, ownerID: owner)
  let root = operation()
  let left = operation(clock: 1)
  let right = operation(clock: 2)
  let a = operation(parent: root.operationID, clock: left.logicalClock, text: "branch A")
  let b = operation(parent: root.operationID, clock: right.logicalClock, text: "branch B")
  try await journal.apply(
    SyncPage(
      ownerID: owner, cursor: 3,
      changes: [
        SyncDelta(cursor: 1, operation: root), SyncDelta(cursor: 2, operation: a),
        SyncDelta(cursor: 3, operation: b),
      ]))
  let offlineChild = operation(parent: a.operationID, clock: 4, text: "offline child")
  try await journal.enqueue(offlineChild)
  let serverResolution = operation(
    parent: root.operationID, clock: 3, text: "earlier resolution",
    resolves: [a.operationID, b.operationID])
  try await journal.apply(
    SyncPage(
      ownerID: owner, cursor: 4, changes: [SyncDelta(cursor: 4, operation: serverResolution)]))
  let state = try await journal.projection(entityID: entity, namespace: .note)
  #expect(state.isConflicted)
  #expect(
    Set(state.candidates.map(\.operationID)) == [
      offlineChild.operationID, serverResolution.operationID,
    ])
  #expect(state.current == a)  // The resolution is also descended from A through its resolves edge.
  #expect(try await journal.cursor() == 4)
  #expect(try await journal.pending() == [offlineChild])
  let staleChoice = operation(
    parent: root.operationID, clock: 5, resolves: [a.operationID, b.operationID])
  await #expect(throws: FoundationStorageError.unresolvedConflict) {
    try await journal.enqueue(staleChoice)
  }
  let finalChoice = operation(
    parent: a.operationID, clock: 6,
    resolves: [offlineChild.operationID, serverResolution.operationID])
  try await journal.enqueue(finalChoice)
  #expect(try await journal.projection(entityID: entity, namespace: .note).current == finalChoice)
}

@Test func simultaneousMergeRevisionsHaveNoArbitraryCommonWinner() async throws {
  let directory = try scratch()
  defer { try? FileManager.default.removeItem(at: directory) }
  let journal = try SyncJournal(directory: directory, ownerID: owner)
  let root = operation()
  let a = operation(parent: root.operationID, clock: 1, text: "A")
  let b = operation(parent: root.operationID, clock: 1, text: "B")
  try await journal.enqueue(root)
  try await journal.enqueue(a)
  try await journal.enqueue(b)
  let first = operation(
    parent: root.operationID, clock: 2, text: "first merge",
    resolves: [a.operationID, b.operationID])
  let second = operation(
    parent: root.operationID, clock: 2, text: "second merge",
    resolves: [a.operationID, b.operationID])
  try await journal.enqueue(first)
  try await journal.apply(
    SyncPage(ownerID: owner, cursor: 1, changes: [SyncDelta(cursor: 1, operation: second)]))
  let state = try await journal.projection(entityID: entity, namespace: .note)
  #expect(state.isConflicted)
  #expect(state.current == nil)  // Both A and B are incomparable common ancestors.
  #expect(Set(state.candidates.map(\.operationID)) == [first.operationID, second.operationID])
}

@Test func unsafeJSONIntegersAndCursorCollisionsAreRejectedAtomically() async throws {
  let directory = try scratch()
  defer { try? FileManager.default.removeItem(at: directory) }
  let journal = try SyncJournal(directory: directory, ownerID: owner)
  await #expect(throws: FoundationStorageError.invalidOperation) {
    try await journal.enqueue(operation(clock: 9_007_199_254_740_992))
  }
  let first = operation()
  try await journal.enqueue(first)
  await #expect(throws: FoundationStorageError.transportRejected) {
    try await journal.acknowledge(
      [SyncAcknowledgement(operationID: first.operationID, cursor: 9_007_199_254_740_992)],
      sent: [first])
  }
  await #expect(throws: FoundationStorageError.invalidCursor) {
    try await journal.apply(
      SyncPage(
        ownerID: owner, cursor: 9_007_199_254_740_992,
        changes: [SyncDelta(cursor: 9_007_199_254_740_992, operation: first)]))
  }
  try await journal.acknowledge(
    [SyncAcknowledgement(operationID: first.operationID, cursor: 1)], sent: [first])
  let second = operation(parent: first.operationID, clock: 1)
  await #expect(throws: FoundationStorageError.invalidCursor) {
    try await journal.apply(
      SyncPage(ownerID: owner, cursor: 1, changes: [SyncDelta(cursor: 1, operation: second)]))
  }
  #expect(try await journal.cursor() == 0)
  #expect(try await journal.projection(entityID: entity, namespace: .note).current == first)
  await #expect(throws: FoundationStorageError.invalidCursor) {
    try await journal.apply(
      SyncPage(ownerID: owner, cursor: 2, changes: [SyncDelta(cursor: 2, operation: first)]))
  }
}

@Test func pulledEchoAcknowledgesDurableOperationAfterLostPushResponse() async throws {
  let directory = try scratch()
  defer { try? FileManager.default.removeItem(at: directory) }
  let journal = try SyncJournal(directory: directory, ownerID: owner)
  let op = operation()
  try await journal.enqueue(op)
  try await journal.apply(
    SyncPage(ownerID: owner, cursor: 1, changes: [SyncDelta(cursor: 1, operation: op)]))
  #expect(try await journal.pending().isEmpty)
  #expect(try await journal.projection(entityID: entity, namespace: .note).current == op)
}

@Test func resolutionCannotConsumeAnAncestorOrUnrelatedBase() async throws {
  let directory = try scratch()
  defer { try? FileManager.default.removeItem(at: directory) }
  let journal = try SyncJournal(directory: directory, ownerID: owner)
  let root = operation()
  let extra = operation(text: "unrelated root")
  let child = operation(parent: root.operationID, clock: 1)
  let branch = operation(parent: root.operationID, clock: 2)
  for op in [root, extra, child, branch] { try await journal.enqueue(op) }
  for invalid in [
    operation(parent: root.operationID, clock: 3, resolves: [root.operationID, child.operationID]),
    operation(
      parent: extra.operationID, clock: 3, resolves: [child.operationID, branch.operationID]),
  ] {
    await #expect(throws: FoundationStorageError.unresolvedConflict) {
      try await journal.apply(
        SyncPage(ownerID: owner, cursor: 1, changes: [SyncDelta(cursor: 1, operation: invalid)]))
    }
  }
  #expect(try await journal.cursor() == 0)
}

@Test func populatedDemoSurvivesV2ToV3IndexMigration() async throws {
  let directory = try scratch()
  defer { try? FileManager.default.removeItem(at: directory) }
  let store = try FoundationStore(directory: directory)
  let fixture = try DemoGenerator.make(yearEnding: Date(timeIntervalSince1970: 1_791_331_200))
  try await store.prepareDemo(fixture)
  let before = try #require(await store.loadDemo())
  let summary = try await store.storageSummary()
  // Reconstruct the exact v2 fixture schema by removing only v3's indexes/receipt.
  // All domain records, manifests, IDs and two-store data stay populated.
  for domain in [StoreDomain.core, .stack] {
    let queue = try DatabaseSchema.open(directory: directory, domain: domain)
    try await queue.write { db in
      try db.execute(
        sql: """
          DROP INDEX foundation_entity_history;
          DROP INDEX foundation_ack_cursor;
          DELETE FROM grdb_migrations WHERE identifier='v3_journal_indexes';
          """)
    }
  }
  let reopened = try FoundationStore(directory: directory)
  let after = try #require(await reopened.loadDemo())
  let encoder = JSONEncoder()
  encoder.outputFormatting = .sortedKeys
  #expect(try encoder.encode(after) == encoder.encode(before))
  let restored = try await reopened.storageSummary()
  #expect(restored.foodLogs == summary.foodLogs)
  #expect(restored.weighIns == summary.weighIns)
  #expect(restored.workouts == summary.workouts && restored.sets == summary.sets)
  #expect(restored.simulationEvents == summary.simulationEvents)
  for domain in [StoreDomain.core, .stack] {
    let queue = try DatabaseSchema.open(directory: directory, domain: domain)
    #expect(
      try await queue.read {
        try Int.fetchOne(
          $0, sql: "SELECT COUNT(*) FROM grdb_migrations WHERE identifier='v3_journal_indexes'")
      } == 1)
  }
}
