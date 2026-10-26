import XCTest
@testable import StackCore

final class ActiveLevelModelTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func after(_ hours: Double) -> Date { t0.addingTimeInterval(hours * 3600) }

    func testUnknownOrInvalidHalfLifeDisablesTheModel() {
        let doses = [DoseEvent(time: t0, amount: 1)]
        XCTAssertNil(ActiveLevelModel.level(at: after(1), doses: doses, halfLifeHours: nil))
        XCTAssertNil(ActiveLevelModel.level(at: after(1), doses: doses, halfLifeHours: 0))
        XCTAssertNil(ActiveLevelModel.level(at: after(1), doses: doses, halfLifeHours: -5))
        XCTAssertNil(ActiveLevelModel.accumulationFactor(intervalHours: 24, halfLifeHours: nil))
    }

    func testInstantAbsorptionHalvesEveryHalfLife() throws {
        let doses = [DoseEvent(time: t0, amount: 1)]
        func level(_ hours: Double) throws -> Double {
            try XCTUnwrap(ActiveLevelModel.level(at: after(hours), doses: doses, halfLifeHours: 24))
        }
        XCTAssertEqual(try level(0), 1, accuracy: 1e-12)
        XCTAssertEqual(try level(24), 0.5, accuracy: 1e-12)
        XCTAssertEqual(try level(48), 0.25, accuracy: 1e-12)
        XCTAssertEqual(try level(-1), 0, accuracy: 1e-12)
    }

    func testDosesAddUp() throws {
        let doses = [DoseEvent(time: t0, amount: 1), DoseEvent(time: after(24), amount: 1)]
        let level = try XCTUnwrap(ActiveLevelModel.level(at: after(24), doses: doses, halfLifeHours: 24))
        XCTAssertEqual(level, 1.5, accuracy: 1e-12)
    }

    func testAccumulationFactor() throws {
        XCTAssertEqual(try XCTUnwrap(ActiveLevelModel.accumulationFactor(intervalHours: 24, halfLifeHours: 24)), 2, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(ActiveLevelModel.accumulationFactor(intervalHours: 48, halfLifeHours: 24)), 4.0 / 3.0, accuracy: 1e-12)
        XCTAssertNil(ActiveLevelModel.accumulationFactor(intervalHours: 0, halfLifeHours: 24))
    }

    func testRepeatedDosingConvergesToTheAccumulationFactor() throws {
        let doses = (0..<20).map { DoseEvent(time: after(Double($0) * 24), amount: 1) }
        let peak = try XCTUnwrap(ActiveLevelModel.level(at: after(19 * 24), doses: doses, halfLifeHours: 24))
        let factor = try XCTUnwrap(ActiveLevelModel.accumulationFactor(intervalHours: 24, halfLifeHours: 24))
        XCTAssertEqual(peak, factor, accuracy: 1e-5)
    }

    func testAbsorptionStartsAtZeroThenPeaksThenDecays() throws {
        let doses = [DoseEvent(time: t0, amount: 1)]
        func level(_ hours: Double) throws -> Double {
            try XCTUnwrap(ActiveLevelModel.level(at: after(hours), doses: doses, halfLifeHours: 24, absorptionRatePerHour: 1))
        }
        XCTAssertEqual(try level(0), 0, accuracy: 1e-12)
        XCTAssertLessThan(try level(1), try level(3.5))
        XCTAssertGreaterThan(try level(3.5), try level(12))
        XCTAssertGreaterThan(try level(12), try level(48))
    }

    func testEqualAbsorptionAndEliminationRatesUseTheLimitForm() throws {
        let ke = log(2.0) / 24
        let doses = [DoseEvent(time: t0, amount: 1)]
        let exact = try XCTUnwrap(ActiveLevelModel.level(at: after(24), doses: doses, halfLifeHours: 24, absorptionRatePerHour: ke))
        XCTAssertEqual(exact, log(2.0) * 0.5, accuracy: 1e-9)

        let nearby = try XCTUnwrap(ActiveLevelModel.level(
            at: after(24), doses: doses, halfLifeHours: 24, absorptionRatePerHour: ke * (1 + 1e-6)))
        XCTAssertEqual(nearby, exact, accuracy: 1e-4)
    }
}
