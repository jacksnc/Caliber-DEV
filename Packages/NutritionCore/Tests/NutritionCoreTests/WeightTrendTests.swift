import XCTest
import HeliosTime
@testable import NutritionCore

final class WeightTrendTests: XCTestCase {
    private let origin = LocalDate(year: 2026, month: 1, day: 1)

    private func entry(_ offset: Int, _ kg: Double) -> WeightEntry {
        WeightEntry(date: origin.addingDays(offset), kg: kg)
    }

    func testFirstValueSeedsTheTrend() {
        let points = WeightTrend.compute([entry(0, 80)])
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].trendKg, 80, accuracy: 1e-12)
    }

    func testNextDayMovesTenPercentOfTheWay() {
        let points = WeightTrend.compute([entry(0, 80), entry(1, 81)])
        XCTAssertEqual(points[1].trendKg, 80.1, accuracy: 1e-9)
    }

    func testGapsUseTheCompoundedGain() {
        // After a 3-day gap the effective gain is 1 - 0.9^3 = 0.271.
        let points = WeightTrend.compute([entry(0, 80), entry(1, 81), entry(4, 79)])
        XCTAssertEqual(points[2].trendKg, 80.1 + 0.271 * (79 - 80.1), accuracy: 1e-9)
    }

    func testSameDayEntriesAreAveragedAndInputOrderDoesNotMatter() {
        let points = WeightTrend.compute([entry(1, 82), entry(0, 80), entry(1, 80)])
        XCTAssertEqual(points.map { $0.date }, [origin, origin.addingDays(1)])
        XCTAssertEqual(points[1].weightKg, 81, accuracy: 1e-12)
        XCTAssertEqual(points[1].trendKg, 80.1, accuracy: 1e-9)
    }

    func testEmptyInputGivesNoPoints() {
        XCTAssertTrue(WeightTrend.compute([]).isEmpty)
    }

    func testRateOfChangeOnASteadyDecline() throws {
        let entries = (0..<60).map { entry($0, 90 - 0.1 * Double($0)) }
        let points = WeightTrend.compute(entries)
        let rate = try XCTUnwrap(WeightTrend.ratePerWeek(points, windowDays: 14))
        XCTAssertEqual(rate, -0.7, accuracy: 0.01)
    }

    func testRateIsNilWithTooLittleData() {
        XCTAssertNil(WeightTrend.ratePerWeek([]))
        let few = WeightTrend.compute([entry(0, 80), entry(1, 80), entry(2, 80)])
        XCTAssertNil(WeightTrend.ratePerWeek(few, windowDays: 14))
    }
}
