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
}
