import Foundation
import CaliberTime

public struct DayIntake: Equatable, Sendable {
    public let date: LocalDate
    public let kcal: Double

    public init(date: LocalDate, kcal: Double) {
        self.date = date
        self.kcal = kcal
    }
}

public enum ExpenditureConfidence: Int, Comparable, Sendable {
    case low = 0
    case medium = 1
    case high = 2

    public static func < (lhs: ExpenditureConfidence, rhs: ExpenditureConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct ExpenditureEstimate: Equatable, Sendable {
    public let tdee: Double
    public let windowDays: Int
    public let loggedDays: Int
    public let coverage: Double
    public let trendChangeKg: Double
    public let trendSpanDays: Int
    public let confidence: ExpenditureConfidence
}

/// Adaptive expenditure (FUEL-22), own implementation of the brief's default:
/// TDEE ~= mean(intake over window) - (change in trend kg * 7,700 / days),
/// window 14-21 days, at least 70% of days logged. Returns nil when the data is not good enough.
public enum ExpenditureEstimator {
    public static func estimate(
        intake: [DayIntake],
        trend: [TrendPoint],
        endingOn end: LocalDate,
        windowDays: Int = 21,
        minCoverage: Double = 0.7,
        minTrendSpanDays: Int = 10,
        kcalPerKg: Double = Energy.kcalPerKgBodyWeight
    ) -> ExpenditureEstimate? {
        guard windowDays >= 1 else { return nil }
        let startDay = end.epochDay - (windowDays - 1)

        let inWindow = intake.filter {
            $0.date.epochDay >= startDay && $0.date.epochDay <= end.epochDay && $0.kcal > 0
        }
        let perDay = Dictionary(grouping: inWindow, by: { $0.date }).mapValues { entries in
            entries.reduce(0.0) { $0 + $1.kcal }
        }
        guard !perDay.isEmpty else { return nil }

        let coverage = Double(perDay.count) / Double(windowDays)
        guard coverage >= minCoverage else { return nil }
        let meanIntake = perDay.values.reduce(0, +) / Double(perDay.count)

        let points = trend
            .filter { $0.date.epochDay >= startDay && $0.date.epochDay <= end.epochDay }
            .sorted { $0.date < $1.date }
        guard let first = points.first, let last = points.last else { return nil }
        let span = last.date.epochDay - first.date.epochDay
        guard span >= minTrendSpanDays else { return nil }

        let change = last.trendKg - first.trendKg
        let tdee = meanIntake - change * kcalPerKg / Double(span)

        var confidence = ExpenditureConfidence.low
        if coverage >= 0.9 && span >= 14 {
            confidence = .high
        } else if coverage >= 0.8 && span >= 10 {
            confidence = .medium
        }

        return ExpenditureEstimate(
            tdee: tdee,
            windowDays: windowDays,
            loggedDays: perDay.count,
            coverage: coverage,
            trendChangeKg: change,
            trendSpanDays: span,
            confidence: confidence
        )
    }
}

public enum TargetAdjuster {
    /// Weekly check-in: move toward the calories that would produce `weeklyRateKg` (negative = loss),
    /// but never by more than `maxStep` kcal from the current target (brief default +/-150).
    public static func nextCalories(
        current: Double,
        tdee: Double,
        weeklyRateKg: Double,
        maxStep: Double = 150,
        kcalPerKg: Double = Energy.kcalPerKgBodyWeight
    ) -> Double {
        let desired = tdee + weeklyRateKg * kcalPerKg / 7
        return min(max(desired, current - maxStep), current + maxStep)
    }
}
