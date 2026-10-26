import XCTest
@testable import TrainingCore
import HeliosTime

final class VolumeEngineTests: XCTestCase {
    private let bench: [MuscleInvolvement] = [.primary(.chest), .secondary(.triceps), .secondary(.frontDelts)]

    private func benchSet(_ date: LocalDate, kind: SetKind = .working, rir: Double? = nil) -> VolumeSet {
        VolumeSet(date: date, kind: kind, weight: 100, reps: 5, rir: rir, involvement: bench)
    }

    func testFractionalContribution() {
        let shares = VolumeEngine.contribution(of: benchSet(LocalDate(year: 2026, month: 10, day: 5)))
        XCTAssertEqual(shares[.chest], 1.0)
        XCTAssertEqual(shares[.triceps], 0.5)
        XCTAssertEqual(shares[.frontDelts], 0.5)
        XCTAssertNil(shares[.lats])
    }

    func testDirectOnlyCountsPrimaryMoversOnly() {
        let policy = VolumeCountingPolicy(fractional: false)
        let shares = VolumeEngine.contribution(of: benchSet(LocalDate(year: 2026, month: 10, day: 5)), policy: policy)
        XCTAssertEqual(shares[.chest], 1.0)
        XCTAssertNil(shares[.triceps])
    }

    func testWarmUpsAreExcludedByDefault() {
        let warmup = benchSet(LocalDate(year: 2026, month: 10, day: 5), kind: .warmup)
        XCTAssertTrue(VolumeEngine.contribution(of: warmup).isEmpty)
    }

    func testHardSetsOnlyDropsEasySetsButKeepsUnloggedRIR() {
        let policy = VolumeCountingPolicy(hardSetsOnly: true, maxRIR: 4)
        let date = LocalDate(year: 2026, month: 10, day: 5)
        XCTAssertTrue(VolumeEngine.contribution(of: benchSet(date, rir: 5), policy: policy).isEmpty)
        XCTAssertFalse(VolumeEngine.contribution(of: benchSet(date, rir: 4), policy: policy).isEmpty)
        XCTAssertFalse(VolumeEngine.contribution(of: benchSet(date, rir: 0), policy: policy).isEmpty)
        XCTAssertFalse(VolumeEngine.contribution(of: benchSet(date, rir: nil), policy: policy).isEmpty)
    }

    func testWeeklyBucketsUseLocalDatesAndMondayStart() throws {
        let monday = LocalDate(year: 2026, month: 10, day: 5)
        let sunday = LocalDate(year: 2026, month: 10, day: 11)
        let nextMonday = LocalDate(year: 2026, month: 10, day: 12)
        let sets = [benchSet(monday), benchSet(monday), benchSet(monday), benchSet(sunday), benchSet(nextMonday)]

        let weeks = VolumeEngine.weekly(sets)
        let first = try XCTUnwrap(weeks[monday])
        let chest = try XCTUnwrap(first[.chest])
        XCTAssertEqual(chest.sets, 4)
        XCTAssertEqual(chest.tonnage, 2000)
        XCTAssertEqual(chest.trainingDays, 2)
        XCTAssertEqual(try XCTUnwrap(first[.triceps]).sets, 2)
        XCTAssertEqual(try XCTUnwrap(first[.triceps]).tonnage, 1000)

        let second = try XCTUnwrap(weeks[nextMonday])
        XCTAssertEqual(try XCTUnwrap(second[.chest]).sets, 1)
        XCTAssertEqual(weeks.count, 2)
    }

    func testSundayWeekStart() throws {
        let monday = LocalDate(year: 2026, month: 10, day: 5)
        let sunday = LocalDate(year: 2026, month: 10, day: 11)
        let nextMonday = LocalDate(year: 2026, month: 10, day: 12)
        let sets = [benchSet(monday), benchSet(monday), benchSet(monday), benchSet(sunday), benchSet(nextMonday)]

        let weeks = VolumeEngine.weekly(sets, firstWeekday: 7)
        XCTAssertEqual(try XCTUnwrap(weeks[LocalDate(year: 2026, month: 10, day: 4)]?[.chest]).sets, 3)
        XCTAssertEqual(try XCTUnwrap(weeks[LocalDate(year: 2026, month: 10, day: 11)]?[.chest]).sets, 2)
    }

    func testVolumeTargetStatusIsNeutralAndInclusive() {
        let target = VolumeTarget.defaultHypertrophy
        XCTAssertEqual(target.status(for: 9), .under)
        XCTAssertEqual(target.status(for: 10), .inRange)
        XCTAssertEqual(target.status(for: 12.5), .inRange)
        XCTAssertEqual(target.status(for: 20), .inRange)
        XCTAssertEqual(target.status(for: 21), .over)
    }

    func testTaxonomyHasAtLeastEighteenRegions() {
        XCTAssertGreaterThanOrEqual(Muscle.allCases.count, 18)
    }
}
