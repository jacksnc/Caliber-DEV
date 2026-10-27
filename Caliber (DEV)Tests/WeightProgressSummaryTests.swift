import Foundation
import Testing
@testable import Caliber__DEV_

@MainActor
struct WeightProgressSummaryTests {
    @Test("No weigh-ins means no invented weight or change")
    func emptySummary() {
        let summary = WeightProgressSummary(entries: [])
        #expect(summary.readings.isEmpty)
        #expect(summary.latestWeightInPounds == nil)
        #expect(summary.changeInPounds == nil)
    }

    @Test("A single weigh-in shows a weight without claiming a trend")
    func singleReading() {
        let summary = WeightProgressSummary(entries: [WeightEntry(date: .now, weightInPounds: 173.25)])
        #expect(summary.latestWeightInPounds == 173.25)
        #expect(summary.changeInPounds == nil)
    }

    @Test("Weights sort by date and preserve fractional changes in either direction")
    func dateOrder() {
        let older = WeightEntry(date: Date(timeIntervalSince1970: 1), weightInPounds: 180.5)
        let newer = WeightEntry(date: Date(timeIntervalSince1970: 2), weightInPounds: 178.25)
        let summary = WeightProgressSummary(entries: [newer, older])
        #expect(summary.readings.first?.id == older.id)
        #expect(summary.latestWeightInPounds == 178.25)
        #expect(summary.changeInPounds == -2.25)
        newer.weightInPounds = 181.75
        #expect(WeightProgressSummary(entries: [older, newer]).changeInPounds == 1.25)
    }

    @Test("Invalid old data cannot corrupt the chart or summary")
    func invalidReadings() {
        let entries = [Double.nan, .infinity, -5, 0, 150.5].map {
            WeightEntry(date: .now, weightInPounds: $0)
        }
        let summary = WeightProgressSummary(entries: entries)
        #expect(summary.readings.count == 1)
        #expect(summary.latestWeightInPounds == 150.5)
        #expect(summary.changeInPounds == nil)
    }

    @Test("The trend follows brief §9.3 and keeps its history across a shorter range")
    func smoothedTrend() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Chicago"))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 7)))
        func day(_ offset: Int, _ pounds: Double) -> WeightEntry {
            WeightEntry(date: calendar.date(byAdding: .day, value: offset, to: start)!, weightInPounds: pounds)
        }
        let history = [day(0, 200), day(1, 190), day(3, 190)]

        let full = WeightProgressSummary(entries: history, calendar: calendar)
        #expect(full.trend.count == 3)
        #expect(abs(full.trend[0].pounds - 200) < 0.0001)
        // One day: gain 0.1. Two days: gain 1 − 0.9² = 0.19.
        #expect(abs(full.trend[1].pounds - 199) < 0.0001)
        #expect(abs(full.trend[2].pounds - (199 - 0.19 * 9)) < 0.0001)
        #expect(abs((full.trendChangeInPounds ?? 0) - (199 - 0.19 * 9 - 200)) < 0.0001)

        // A range holding only the last day still carries the earlier trend.
        let recent = WeightProgressSummary(entries: [history[2]], history: history, calendar: calendar)
        #expect(recent.trend.count == 1)
        #expect(abs((recent.latestTrendInPounds ?? 0) - full.trend[2].pounds) < 0.0001)
        #expect(recent.trendChangeInPounds == nil)
    }
}
