import XCTest
import HeliosTime
@testable import InsightsCore

final class CorrelationTests: XCTestCase {
    private let base = LocalDate(year: 2026, month: 10, day: 1)

    private func series(_ values: [Double], startingAt offset: Int = 0) -> [LocalDate: Double] {
        var result: [LocalDate: Double] = [:]
        for (index, value) in values.enumerated() { result[base.addingDays(offset + index)] = value }
        return result
    }

    func testTooFewPairsGivesNoResult() {
        let a = series((0..<10).map(Double.init))
        XCTAssertNil(CorrelationExplorer.analyze(a: a, b: a))
    }

    func testPerfectMonotonicRelationship() throws {
        let a = series((0..<20).map(Double.init))
        let b = series((0..<20).map { Double($0 * $0) })
        let result = try XCTUnwrap(CorrelationExplorer.analyze(a: a, b: b))
        XCTAssertEqual(result.rho, 1, accuracy: 1e-12)
        XCTAssertEqual(result.pairs, 20)
        XCTAssertEqual(result.coverage, 1, accuracy: 1e-12)
        XCTAssertGreaterThan(try XCTUnwrap(result.confidenceInterval).lowerBound, 0.99)
    }

    func testNegativeRelationship() throws {
        let a = series((0..<20).map(Double.init))
        let b = series((0..<20).map { -Double($0) })
        XCTAssertEqual(try XCTUnwrap(CorrelationExplorer.analyze(a: a, b: b)).rho, -1, accuracy: 1e-12)
    }

    func testLagFindsADelayedRelationship() throws {
        // r is a scrambled sequence; b repeats it two days later.
        let r = (0..<20).map { Double(($0 * 7) % 20) }
        let a = series(r)
        let b = series(r, startingAt: 2)

        let lagged = try XCTUnwrap(CorrelationExplorer.analyze(a: a, b: b, lagDays: 2))
        XCTAssertEqual(lagged.rho, 1, accuracy: 1e-12)
        XCTAssertEqual(lagged.pairs, 20)
        XCTAssertEqual(lagged.lagDays, 2)

        let unlagged = try XCTUnwrap(CorrelationExplorer.analyze(a: a, b: b, lagDays: 0))
        XCTAssertLessThan(unlagged.rho, 0.99)
        XCTAssertEqual(unlagged.pairs, 18)
    }

    func testConstantSeriesHasNoCorrelation() {
        let a = series((0..<20).map(Double.init))
        let flat = series([Double](repeating: 5, count: 20))
        XCTAssertNil(CorrelationExplorer.analyze(a: a, b: flat))
    }

    func testResultsAreReproducible() throws {
        let r = (0..<25).map { Double(($0 * 11) % 25) }
        let a = series(r)
        let b = series(r.enumerated().map { $1 + Double($0 % 4) })
        let first = try XCTUnwrap(CorrelationExplorer.analyze(a: a, b: b, seed: 7))
        let second = try XCTUnwrap(CorrelationExplorer.analyze(a: a, b: b, seed: 7))
        XCTAssertEqual(first, second)
        XCTAssertEqual(CorrelationExplorer.caveat, "Association, not cause.")
    }

    // MARK: dose-cycle overlay

    func testAveragesByDaysSinceTheLastDose() {
        let values: [Double] = [100, 60, 70, 95, 100, 100, 100, 100, 62, 72, 94, 99, 100, 101]
        var data = series(values)
        data[base.addingDays(-3)] = 999   // before the first dose: ignored
        let doses = [base, base.addingDays(7)]

        let buckets = DoseCycleOverlay.averageByDaysSinceDose(series: data, doseDates: doses)
        XCTAssertEqual(buckets.map { $0.daysSinceDose }, [0, 1, 2, 3, 4, 5, 6])
        XCTAssertEqual(buckets.map { $0.mean }, [100, 61, 71, 94.5, 99.5, 100, 100.5])
        XCTAssertEqual(buckets.map { $0.count }, [2, 2, 2, 2, 2, 2, 2])
    }

    func testOverlayHonoursMaxDaysAndEmptyInput() {
        let data = series([100, 60, 70, 95, 100, 100, 100, 100, 62, 72, 94, 99, 100, 101])
        let doses = [base, base.addingDays(7)]
        XCTAssertEqual(DoseCycleOverlay.averageByDaysSinceDose(series: data, doseDates: doses, maxDays: 3).count, 4)
        XCTAssertTrue(DoseCycleOverlay.averageByDaysSinceDose(series: data, doseDates: []).isEmpty)
        XCTAssertTrue(DoseCycleOverlay.averageByDaysSinceDose(series: [:], doseDates: doses).isEmpty)
    }

    func testDaysBeyondTheWindowAreDropped() {
        // One dose, then 12 days of data: only days 0...7 are kept by default.
        let data = series((0..<12).map { _ in 50 })
        let buckets = DoseCycleOverlay.averageByDaysSinceDose(series: data, doseDates: [base])
        XCTAssertEqual(buckets.count, 8)
        XCTAssertEqual(buckets.last?.daysSinceDose, 7)
    }
}
