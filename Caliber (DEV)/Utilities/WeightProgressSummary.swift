import Foundation
import HeliosTime
import NutritionCore

/// Uses only recorded, valid weigh-ins. Notes and photos never imply a weight.
@MainActor
struct WeightProgressSummary {
    let readings: [WeightEntry]

    /// One day of the smoothed trend (brief §9.3), placed at noon of its local date.
    struct TrendReading: Identifiable, Equatable {
        let date: Date
        let pounds: Double
        var id: Date { date }
    }

    /// The trend for the days in `entries`. It is computed over `history` (every weigh-in) so a
    /// short range does not restart the trend at its first reading.
    let trend: [TrendReading]

    init(entries: [WeightEntry], history: [WeightEntry]? = nil, calendar: Calendar = .current) {
        readings = entries.filter { $0.weightInPounds.isFinite && $0.weightInPounds > 0 }
            .sorted {
                if $0.date != $1.date { return $0.date < $1.date }
                return $0.id.uuidString < $1.id.uuidString
            }
        trend = Self.trend(
            for: readings, history: history ?? entries, calendar: calendar)
    }

    var latestTrendInPounds: Double? { trend.last?.pounds }

    /// Change in the trend across the shown days; nil until there are two days.
    var trendChangeInPounds: Double? {
        guard trend.count > 1, let first = trend.first, let last = trend.last else { return nil }
        return last.pounds - first.pounds
    }

    private static let kilogramsPerPound = 0.45359237

    private static func trend(
        for readings: [WeightEntry], history: [WeightEntry], calendar: Calendar
    ) -> [TrendReading] {
        func day(_ date: Date) -> LocalDate {
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return LocalDate(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
        }
        guard let first = readings.first, let last = readings.last else { return [] }
        let shown = day(first.date)...day(last.date)
        let input = history.filter { $0.weightInPounds.isFinite && $0.weightInPounds > 0 }
            .map {
                NutritionCore.WeightEntry(
                    date: day($0.date), kg: $0.weightInPounds * kilogramsPerPound)
            }
        return WeightTrend.compute(input).compactMap { point in
            guard shown.contains(point.date),
                let date = calendar.date(
                    from: DateComponents(
                        year: point.date.year, month: point.date.month, day: point.date.day,
                        hour: 12))
            else { return nil }
            return TrendReading(date: date, pounds: point.trendKg / kilogramsPerPound)
        }
    }

    var latestWeightInPounds: Double? { readings.last?.weightInPounds }

    /// A positive number means an increase; a negative number means a decrease.
    var changeInPounds: Double? {
        guard readings.count > 1, let first = readings.first, let last = readings.last else { return nil }
        return last.weightInPounds - first.weightInPounds
    }
}
