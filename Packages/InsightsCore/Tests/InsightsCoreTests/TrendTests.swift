import XCTest
import HeliosTime
@testable import InsightsCore

final class TrendTests: XCTestCase {
    private let base = LocalDate(year: 2026, month: 8, day: 3)

    private func weekly(_ values: [Double]) -> [SeriesPoint] {
        values.enumerated().map { SeriesPoint(date: base.addingDays($0.offset * 7), value: $0.element) }
    }

    func testTooFewPointsOrTooShortASpan() {
        XCTAssertEqual(TrendAnalyzer.evaluate(weekly([100, 101, 102, 103])), .insufficientData)
        let tight = (0..<6).map { SeriesPoint(date: base.addingDays($0), value: Double($0)) }
        XCTAssertEqual(TrendAnalyzer.evaluate(tight), .insufficientData)
        XCTAssertEqual(TrendAnalyzer.evaluate([]), .insufficientData)
    }

    func testClearUpwardTrendAndItsSentence() throws {
        // +0.75 per week for 8 weeks: +6 on a start of 100.
        let points = weekly((0...8).map { 100 + 0.75 * Double($0) })
        guard case let .trend(trend) = TrendAnalyzer.evaluate(points) else { return XCTFail("expected a trend") }
        XCTAssertEqual(trend.spanDays, 56)
        XCTAssertEqual(trend.totalChange, 6, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(trend.percentChange), 6, accuracy: 1e-6)
        XCTAssertEqual(InsightText.sentence(for: trend, label: "Squat e1RM"), "Squat e1RM +6% in 8 weeks")
    }

    func testClearDownwardTrendUsesOneDecimalForSmallPercentages() throws {
        let points = weekly((0...8).map { 90 - 0.5 * Double($0) })
        guard case let .trend(trend) = TrendAnalyzer.evaluate(points) else { return XCTFail("expected a trend") }
        XCTAssertEqual(trend.totalChange, -4, accuracy: 1e-9)
        XCTAssertEqual(InsightText.sentence(for: trend, label: "Weight"), "Weight -4.4% in 8 weeks")
    }

    func testSeriesCrossingZeroReportsAbsoluteChange() {
        let points = weekly((0...8).map(Double.init))
        guard case let .trend(trend) = TrendAnalyzer.evaluate(points) else { return XCTFail("expected a trend") }
        XCTAssertNil(trend.percentChange)
        XCTAssertEqual(InsightText.sentence(for: trend, label: "Net change", unit: "kg"), "Net change +8 kg in 8 weeks")
    }

    func testFlatNoisyDataIsNotATrend() {
        let points = weekly([100, 101, 100, 101, 100, 101, 100, 101, 100])
        XCTAssertEqual(TrendAnalyzer.evaluate(points), .noClearTrend)
    }

    func testPerfectlyFlatDataIsNotATrend() {
        XCTAssertEqual(TrendAnalyzer.evaluate(weekly([Double](repeating: 80, count: 8))), .noClearTrend)
    }

    func testNoisyDataWithAWeakSlopeIsNotATrend() {
        // A 1 kg rise buried in +/-10 swings.
        let points = weekly([100, 110, 92, 108, 95, 112, 94, 109, 101])
        XCTAssertEqual(TrendAnalyzer.evaluate(points), .noClearTrend)
    }

    func testSentencesForTheNonTrendStates() {
        XCTAssertEqual(InsightText.sentence(for: .insufficientData, label: "Squat e1RM"), "Not enough Squat e1RM data yet")
        XCTAssertEqual(InsightText.sentence(for: .noClearTrend, label: "Squat e1RM"), "No clear Squat e1RM trend yet")
    }

    func testShortSpansAreDescribedInDays() {
        let trend = TrendInsight.Trend(slopePerDay: 1, spanDays: 10, totalChange: 10, percentChange: nil, noise: 0)
        XCTAssertEqual(InsightText.sentence(for: trend, label: "Steps"), "Steps +10 in 10 days")
    }

    // MARK: stalls

    func testStallWhenTheLastFourWeeksHoldNoNewBest() {
        let points = weekly([100, 102, 104, 106, 106, 105, 106, 105.5])
        XCTAssertEqual(StallDetector.evaluate(points), .stalled(inDeficit: false))
        XCTAssertEqual(StallDetector.evaluate(points, inDeficit: true), .stalled(inDeficit: true))
    }

    func testProgressingWhenARecentSessionSetsANewBest() {
        let points = weekly([100, 102, 104, 106, 106, 105, 108, 105.5])
        XCTAssertEqual(StallDetector.evaluate(points), .progressing)
    }

    func testStallNeedsEnoughRecentSessionsAndHistory() {
        XCTAssertEqual(StallDetector.evaluate(weekly([100, 102, 104, 106, 107, 108]), windowWeeks: 4, minSessions: 5), .insufficientData)
        XCTAssertEqual(StallDetector.evaluate(weekly([100, 101, 102])), .insufficientData)
        XCTAssertEqual(StallDetector.evaluate([]), .insufficientData)
    }
}
