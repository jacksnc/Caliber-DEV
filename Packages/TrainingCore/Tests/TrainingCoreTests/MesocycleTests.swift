import XCTest
@testable import TrainingCore

final class MesocycleTests: XCTestCase {
    func testVolumeRampRisesToTheCeilingThenDeloads() {
        let plan = MesocyclePlanner.volumeRamp(
            start: [.chest: 10, .triceps: 6], weeks: 5, increment: 1, ceiling: [.chest: 13])
        XCTAssertEqual(plan.count, 5)
        XCTAssertEqual(plan.map { $0[.chest] ?? -1 }, [10, 11, 12, 13, 6.5])
        XCTAssertEqual(plan.map { $0[.triceps] ?? -1 }, [6, 7, 8, 9, 4.5])
    }

    func testCeilingStopsFurtherGrowth() {
        let plan = MesocyclePlanner.volumeRamp(start: [.chest: 12], weeks: 6, increment: 2, ceiling: [.chest: 14])
        XCTAssertEqual(plan.map { $0[.chest] ?? -1 }, [12, 14, 14, 14, 14, 7])
    }

    func testTooShortABlockReturnsTheStart() {
        let plan = MesocyclePlanner.volumeRamp(start: [.quads: 8], weeks: 1)
        XCTAssertEqual(plan.count, 1)
        XCTAssertEqual(plan[0][.quads], 8)
        XCTAssertEqual(MesocyclePlanner.volumeRamp(start: [.quads: 8], weeks: 2).map { $0[.quads] ?? -1 }, [8, 4])
    }

    func testDeloadTriggers() {
        let good = SessionFeedback(performance: .improved)
        let bad = SessionFeedback(performance: .declined)
        XCTAssertTrue(MesocyclePlanner.shouldDeload(recent: [good, bad, bad], atCeiling: false))
        XCTAssertFalse(MesocyclePlanner.shouldDeload(recent: [bad, good, bad], atCeiling: false))
        XCTAssertFalse(MesocyclePlanner.shouldDeload(recent: [bad], atCeiling: false))
        XCTAssertTrue(MesocyclePlanner.shouldDeload(recent: [good], atCeiling: true))
        XCTAssertFalse(MesocyclePlanner.shouldDeload(recent: [], atCeiling: false))
    }

    func testNextWeekSets() {
        XCTAssertEqual(MesocyclePlanner.nextWeekSets(current: 10, feedback: SessionFeedback(performance: .improved), ceiling: 20), 11)
        XCTAssertEqual(MesocyclePlanner.nextWeekSets(current: 10, feedback: SessionFeedback(performance: .declined), ceiling: 20), 10)
        XCTAssertEqual(MesocyclePlanner.nextWeekSets(current: 10, feedback: SessionFeedback(performance: .steady, soreness: 2), ceiling: 20), 10)
        XCTAssertEqual(MesocyclePlanner.nextWeekSets(current: 20, feedback: SessionFeedback(performance: .improved), ceiling: 20), 20)
    }
}
