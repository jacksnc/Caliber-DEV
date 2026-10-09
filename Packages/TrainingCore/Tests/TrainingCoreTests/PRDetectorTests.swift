import XCTest
@testable import TrainingCore

final class PRDetectorTests: XCTestCase {
    private let sessionA = UUID()
    private let sessionB = UUID()
    private let sessionC = UUID()

    private func make(_ weight: Double, _ reps: Int, day: Int, session: UUID, kind: SetKind = .working, rpe: Double? = nil) -> LoggedSet {
        LoggedSet(
            sessionID: session,
            completedAt: Date(timeIntervalSince1970: Double(day) * 86_400),
            weight: weight,
            reps: reps,
            kind: kind,
            rpe: rpe
        )
    }

    private func repRecordReps(_ result: PRResult) -> [Int] {
        result.kinds.compactMap { kind -> Int? in
            if case let .repRecord(reps, _) = kind { return reps }
            return nil
        }.sorted()
    }

    private func has(_ result: PRResult, where match: (PRKind) -> Bool) -> Bool {
        result.kinds.contains(where: match)
    }

    func testFirstEverSetIsNotAPR() {
        let result = PRDetector.evaluate(make(100, 5, day: 1, session: sessionA), history: [])
        XCTAssertTrue(result.isFirstEntry)
        XCTAssertFalse(result.isPR)
    }

    func testMoreRepsAtTheSameWeightFollowsTheAtLeastNRule() throws {
        let first = make(100, 5, day: 1, session: sessionA)
        let next = make(100, 8, day: 2, session: sessionB)
        let result = PRDetector.evaluate(next, history: [first])

        XCTAssertEqual(repRecordReps(result), [6, 7, 8])
        XCTAssertEqual(result.headlineRepRecord, .repRecord(reps: 8, weight: 100))
        XCTAssertTrue(has(result) { if case .bestSetVolume(let v) = $0 { return v == 800 } else { return false } })
        XCTAssertTrue(has(result) { if case .bestE1RM = $0 { return true } else { return false } })
        XCTAssertFalse(has(result) { if case .heaviestWeight = $0 { return true } else { return false } })
    }

    func testHeavierWeightForFewerRepsIsARepRecordButNotE1RMOrVolume() {
        let first = make(100, 5, day: 1, session: sessionA)
        let next = make(105, 3, day: 2, session: sessionB)
        let result = PRDetector.evaluate(next, history: [first])

        XCTAssertEqual(repRecordReps(result), [1, 2, 3])
        XCTAssertTrue(has(result) { if case .heaviestWeight(let w) = $0 { return w == 105 } else { return false } })
        XCTAssertFalse(has(result) { if case .bestE1RM = $0 { return true } else { return false } })
        XCTAssertFalse(has(result) { if case .bestSetVolume = $0 { return true } else { return false } })
    }

    func testTyingAnExistingBestIsNotAPR() {
        let first = make(100, 5, day: 1, session: sessionA)
        let tie = make(100, 5, day: 2, session: sessionB)
        let result = PRDetector.evaluate(tie, history: [first])
        XCTAssertFalse(result.isPR)
        XCTAssertFalse(result.isFirstEntry)
    }

    func testWarmUpsNeverCountOrBeatAnything() {
        let first = make(100, 5, day: 1, session: sessionA)
        let warmup = make(200, 1, day: 2, session: sessionB, kind: .warmup)
        XCTAssertFalse(PRDetector.evaluate(warmup, history: [first]).isPR)

        // A warm-up in the history is invisible, so the first working set is still a "first entry".
        let working = make(100, 5, day: 3, session: sessionB)
        let oldWarmup = make(200, 5, day: 1, session: sessionA, kind: .warmup)
        XCTAssertTrue(PRDetector.evaluate(working, history: [oldWarmup]).isFirstEntry)
    }

    func testLaterSetsInTheHistoryAreIgnored() {
        let early = make(100, 5, day: 1, session: sessionA)
        let target = make(110, 5, day: 2, session: sessionB)
        let later = make(150, 5, day: 3, session: sessionC)
        let result = PRDetector.evaluate(target, history: [early, later])
        XCTAssertTrue(has(result) { if case .heaviestWeight = $0 { return true } else { return false } })
    }

    func testLowConfidenceSetsAreExcludedFromE1RMRecords() {
        let first = make(100, 5, day: 1, session: sessionA)
        let highReps = make(60, 20, day: 2, session: sessionB)
        let result = PRDetector.evaluate(highReps, history: [first])

        XCTAssertFalse(has(result) { if case .bestE1RM = $0 { return true } else { return false } })
        XCTAssertTrue(has(result) { if case .bestSetVolume(let v) = $0 { return v == 1200 } else { return false } })
        XCTAssertEqual(repRecordReps(result), [6, 7, 8, 9, 10, 11, 12])
    }

    func testRecordsRecomputeFromRawHistory() throws {
        let s1 = make(100, 5, day: 1, session: sessionA)
        let s2 = make(100, 8, day: 2, session: sessionB)
        let s3 = make(105, 3, day: 2, session: sessionB)
        let warmup = make(200, 1, day: 2, session: sessionB, kind: .warmup)

        let all = ExerciseRecords.compute(from: [s1, s2, s3, warmup])
        XCTAssertEqual(all.heaviestWeight, 105)
        XCTAssertEqual(all.bestSetVolume, 800)
        XCTAssertEqual(all.bestSessionVolume, 800 + 315)
        let expectedE1RM = try XCTUnwrap(OneRepMax.estimate(weight: 100, reps: 8))
        XCTAssertEqual(try XCTUnwrap(all.bestE1RM), expectedE1RM, accuracy: 1e-9)
        XCTAssertEqual(all.repMaxGrid[1], 105)
        XCTAssertEqual(all.repMaxGrid[3], 105)
        XCTAssertEqual(all.repMaxGrid[4], 100)
        XCTAssertEqual(all.repMaxGrid[8], 100)
        XCTAssertNil(all.repMaxGrid[9])

        // Deleting the 105 set must lower the records (edits and deletes stay correct).
        let afterDelete = ExerciseRecords.compute(from: [s1, s2, warmup])
        XCTAssertEqual(afterDelete.heaviestWeight, 100)
        XCTAssertEqual(afterDelete.repMaxGrid[1], 100)
        XCTAssertEqual(afterDelete.bestSessionVolume, 800)
    }

    func testEmptyHistoryHasEmptyRecords() {
        let records = ExerciseRecords.compute(from: [])
        XCTAssertEqual(records.heaviestWeight, 0)
        XCTAssertNil(records.bestE1RM)
        XCTAssertTrue(records.repMaxGrid.isEmpty)
    }

    func testSessionVolumeRecord() {
        let a = make(100, 5, day: 1, session: sessionA)
        let b1 = make(100, 8, day: 2, session: sessionB)
        let b2 = make(105, 3, day: 2, session: sessionB)
        let c = make(100, 5, day: 3, session: sessionC)
        let all = [a, b1, b2, c]

        XCTAssertFalse(PRDetector.isSessionVolumeRecord(sessionID: sessionA, in: all))
        XCTAssertTrue(PRDetector.isSessionVolumeRecord(sessionID: sessionB, in: all))
        XCTAssertFalse(PRDetector.isSessionVolumeRecord(sessionID: sessionC, in: all))
    }
}
