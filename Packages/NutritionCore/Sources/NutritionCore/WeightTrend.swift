import Foundation
import HeliosTime

public struct WeightEntry: Equatable, Sendable {
    public let date: LocalDate
    public let kg: Double

    public init(date: LocalDate, kg: Double) {
        self.date = date
        self.kg = kg
    }
}

public struct TrendPoint: Equatable, Sendable {
    public let date: LocalDate
    public let weightKg: Double
    public let trendKg: Double

    public init(date: LocalDate, weightKg: Double, trendKg: Double) {
        self.date = date
        self.weightKg = weightKg
        self.trendKg = trendKg
    }
}

/// Exponentially weighted moving average trend (brief §9.3):
/// trend_t = trend_(t-1) + alpha * (w_t - trend_(t-1)), alpha = 0.1, the first value seeds the trend,
/// and across a gap of n days the effective gain is 1 - (1 - alpha)^n.
public enum WeightTrend {
    public static let defaultAlpha = 0.1

    public static func compute(_ entries: [WeightEntry], alpha: Double = WeightTrend.defaultAlpha) -> [TrendPoint] {
        let byDay = Dictionary(grouping: entries, by: { $0.date })
        let days = byDay.keys.sorted()

        var points: [TrendPoint] = []
        var trend = 0.0
        var previous: LocalDate?

        for day in days {
            let weights = (byDay[day] ?? []).map { $0.kg }
            guard !weights.isEmpty else { continue }
            let weight = weights.reduce(0, +) / Double(weights.count)

            if let previousDay = previous {
                let gap = Double(day.epochDay - previousDay.epochDay)
                let gain = 1 - pow(1 - alpha, gap)
                trend += gain * (weight - trend)
            } else {
                trend = weight
            }
            points.append(TrendPoint(date: day, weightKg: weight, trendKg: trend))
            previous = day
        }
        return points
    }

    /// Change of the trend in kg per week over the most recent `windowDays`, or nil with too little data.
    public static func ratePerWeek(_ points: [TrendPoint], windowDays: Int = 14) -> Double? {
        guard let last = points.last else { return nil }
        let cutoff = last.date.epochDay - windowDays
        guard let first = points.first(where: { $0.date.epochDay >= cutoff }) else { return nil }
        let span = Double(last.date.epochDay - first.date.epochDay)
        guard span > 0, span >= Double(windowDays) / 2 else { return nil }
        return (last.trendKg - first.trendKg) / span * 7
    }
}
