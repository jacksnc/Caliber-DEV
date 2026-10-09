import XCTest
import CaliberTime
@testable import NutritionCore

final class ExpenditureTests: XCTestCase {
    private let end = LocalDate(year: 2026, month: 10, day: 9)

    private func day(_ index: Int) -> LocalDate { LocalDate(epochDay: end.epochDay - 20 + index) }

    private func intake(_ kcal: Double, days: [Int]) -> [DayIntake] {
        days.map { DayIntake(date: day($0), kcal: kcal) }
    }

    private func flatTrend(_ kg: Double = 80, days: [Int] = Array(0...20)) -> [TrendPoint] {
        days.map { TrendPoint(date: day($0), weightKg: kg, trendKg: kg) }
    }

    func testFlatWeightMeansIntakeEqualsExpenditure() throws {
        let estimate = try XCTUnwrap(ExpenditureEstimator.estimate(
            intake: intake(2500, days: Array(0...20)), trend: flatTrend(), endingOn: end))
        XCTAssertEqual(estimate.tdee, 2500, accuracy: 0.01)
        XCTAssertEqual(estimate.loggedDays, 21)
        XCTAssertEqual(estimate.coverage, 1, accuracy: 1e-12)
        XCTAssertEqual(estimate.confidence, .high)
    }

    func testLosingWeightMeansExpenditureExceedsIntake() throws {
        // Trend falls 20/14 kg over 20 days = 550 kcal/day deficit; eating 2000 means TDEE is 2550.
        let falling = (0...20).map { TrendPoint(date: day($0), weightKg: 80, trendKg: 80 - Double($0) / 14) }
        let estimate = try XCTUnwrap(ExpenditureEstimator.estimate(
            intake: intake(2000, days: Array(0...20)), trend: falling, endingOn: end))
        XCTAssertEqual(estimate.tdee, 2550, accuracy: 0.01)
        XCTAssertEqual(estimate.trendSpanDays, 20)
    }

    func testCoverageGateAtSeventyPercent() {
        let fifteen = Array(0..<15)   // 15 of 21 = 71.4%
        let fourteen = Array(0..<14)  // 14 of 21 = 66.7%
        let ok = ExpenditureEstimator.estimate(intake: intake(2500, days: fifteen), trend: flatTrend(), endingOn: end)
        let tooFew = ExpenditureEstimator.estimate(intake: intake(2500, days: fourteen), trend: flatTrend(), endingOn: end)
        XCTAssertNotNil(ok)
        XCTAssertEqual(ok?.confidence, .low)
        XCTAssertNil(tooFew)
    }

    func testConfidenceTiers() throws {
        let medium = try XCTUnwrap(ExpenditureEstimator.estimate(
            intake: intake(2500, days: Array(0..<17)), trend: flatTrend(), endingOn: end))  // 81%
        XCTAssertEqual(medium.confidence, .medium)
        let high = try XCTUnwrap(ExpenditureEstimator.estimate(
            intake: intake(2500, days: Array(0..<19)), trend: flatTrend(), endingOn: end))  // 90.5%
        XCTAssertEqual(high.confidence, .high)
    }

    func testShortTrendSpanIsRejected() {
        let shortTrend = flatTrend(days: [16, 17, 18, 19, 20])
        XCTAssertNil(ExpenditureEstimator.estimate(intake: intake(2500, days: Array(0...20)), trend: shortTrend, endingOn: end))
    }

    func testNoDataIsRejected() {
        XCTAssertNil(ExpenditureEstimator.estimate(intake: [], trend: flatTrend(), endingOn: end))
        XCTAssertNil(ExpenditureEstimator.estimate(intake: intake(2500, days: Array(0...20)), trend: [], endingOn: end))
    }

    func testMultipleEntriesOnOneDayAreSummed() throws {
        var entries = intake(1200, days: Array(0...20))
        entries += intake(1300, days: Array(0...20))
        let estimate = try XCTUnwrap(ExpenditureEstimator.estimate(intake: entries, trend: flatTrend(), endingOn: end))
        XCTAssertEqual(estimate.tdee, 2500, accuracy: 0.01)
    }

    func testWeeklyAdjustmentIsClampedToTheStep() {
        // Wants 2550 - 550 = 2000.
        XCTAssertEqual(TargetAdjuster.nextCalories(current: 2300, tdee: 2550, weeklyRateKg: -0.5), 2150, accuracy: 1e-9)
        XCTAssertEqual(TargetAdjuster.nextCalories(current: 2100, tdee: 2550, weeklyRateKg: -0.5), 2000, accuracy: 1e-9)
        XCTAssertEqual(TargetAdjuster.nextCalories(current: 1700, tdee: 2550, weeklyRateKg: -0.5), 1850, accuracy: 1e-9)
    }
}
