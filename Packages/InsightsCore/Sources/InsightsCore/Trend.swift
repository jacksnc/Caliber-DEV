import Foundation
import CaliberTime

public struct SeriesPoint: Equatable, Sendable {
    public let date: LocalDate
    public let value: Double

    public init(date: LocalDate, value: Double) {
        self.date = date
        self.value = value
    }
}

public enum TrendInsight: Equatable, Sendable {
    public struct Trend: Equatable, Sendable {
        public let slopePerDay: Double
        public let spanDays: Int
        public let totalChange: Double
        /// Change as a percentage of the fitted starting value, when that is not about zero.
        public let percentChange: Double?
        public let noise: Double
    }

    case insufficientData
    case noClearTrend
    case trend(Trend)
}

/// Trend gate (brief §3.5): enough points, enough time, and the fitted change must exceed twice the
/// median absolute deviation of the residuals. Otherwise the UI says "No clear trend yet".
public enum TrendAnalyzer {
    public static func evaluate(_ points: [SeriesPoint], minPoints: Int = 5, minSpanDays: Int = 14) -> TrendInsight {
        let sorted = points.sorted { $0.date < $1.date }
        guard sorted.count >= minPoints, let first = sorted.first, let last = sorted.last else { return .insufficientData }
        let span = last.date.epochDay - first.date.epochDay
        guard span >= minSpanDays else { return .insufficientData }

        let xs = sorted.map { Double($0.date.epochDay - first.date.epochDay) }
        let ys = sorted.map { $0.value }
        guard let line = Stats.theilSen(x: xs, y: ys) else { return .insufficientData }

        let residuals = zip(xs, ys).map { pair in pair.1 - (line.slope * pair.0 + line.intercept) }
        let noise = Stats.mad(residuals) ?? 0
        let change = line.slope * Double(span)

        guard change != 0, abs(change) > 2 * noise else { return .noClearTrend }

        let percent: Double? = abs(line.intercept) > 1e-9 ? change / line.intercept * 100 : nil
        return .trend(TrendInsight.Trend(
            slopePerDay: line.slope, spanDays: span, totalChange: change, percentChange: percent, noise: noise
        ))
    }
}

/// Templated, deterministic sentences. AI may rephrase them but never invent them.
public enum InsightText {
    public static func sentence(for trend: TrendInsight.Trend, label: String, unit: String = "") -> String {
        let sign = trend.totalChange >= 0 ? "+" : "-"
        let amount: String
        if let percent = trend.percentChange {
            amount = "\(sign)\(number(abs(percent)))%"
        } else {
            let suffix = unit.isEmpty ? "" : " \(unit)"
            amount = "\(sign)\(number(abs(trend.totalChange)))\(suffix)"
        }
        return "\(label) \(amount) in \(duration(days: trend.spanDays))"
    }

    public static func sentence(for insight: TrendInsight, label: String, unit: String = "") -> String {
        switch insight {
        case .insufficientData: return "Not enough \(label) data yet"
        case .noClearTrend: return "No clear \(label) trend yet"
        case let .trend(trend): return sentence(for: trend, label: label, unit: unit)
        }
    }

    static func duration(days: Int) -> String {
        if days < 14 { return "\(days) days" }
        let weeks = Int((Double(days) / 7).rounded())
        return "\(weeks) weeks"
    }

    static func number(_ value: Double) -> String {
        if value >= 10 { return String(Int(value.rounded())) }
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(rounded)
    }
}

public enum StallStatus: Equatable, Sendable {
    case insufficientData
    case progressing
    /// `inDeficit` lets the UI say a stall is expected while the user is eating below maintenance.
    case stalled(inDeficit: Bool)
}

/// Stall detection (TRN-45): no new best in the last `windowWeeks` compared with everything before it.
public enum StallDetector {
    public static func evaluate(
        _ points: [SeriesPoint],
        windowWeeks: Int = 4,
        minSessions: Int = 3,
        inDeficit: Bool = false
    ) -> StallStatus {
        let sorted = points.sorted { $0.date < $1.date }
        guard let last = sorted.last else { return .insufficientData }
        let windowStart = last.date.epochDay - 7 * windowWeeks

        let recent = sorted.filter { $0.date.epochDay > windowStart }
        let earlier = sorted.filter { $0.date.epochDay <= windowStart }
        guard recent.count >= minSessions,
              let bestEarlier = earlier.map({ $0.value }).max(),
              let bestRecent = recent.map({ $0.value }).max() else { return .insufficientData }

        return bestRecent > bestEarlier ? .progressing : .stalled(inDeficit: inDeficit)
    }
}
