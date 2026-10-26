import Foundation

public enum PerformanceTrend: Int, Sendable {
    case declined = -1
    case steady = 0
    case improved = 1
}

/// Quick post-session feedback (brief TRN-44: soreness, pump, performance).
public struct SessionFeedback: Equatable, Sendable {
    public let performance: PerformanceTrend
    /// 0 = none, 1 = mild, 2 = lingering/high.
    public let soreness: Int
    /// 0 = flat, 1 = good, 2 = great.
    public let pump: Int

    public init(performance: PerformanceTrend, soreness: Int = 0, pump: Int = 1) {
        self.performance = performance
        self.soreness = soreness
        self.pump = pump
    }
}

/// RP-style mesocycle helper. Volume landmarks are editable heuristics, not rules.
public enum MesocyclePlanner {
    /// Weekly set targets per muscle: the first week uses `start`, each loading week adds `increment`
    /// (capped at the muscle's `ceiling` when given), and the final week is a deload at `deloadFactor`
    /// of the previous week's volume.
    public static func volumeRamp(
        start: [Muscle: Double],
        weeks: Int,
        increment: Double = 1,
        ceiling: [Muscle: Double] = [:],
        deloadFactor: Double = 0.5
    ) -> [[Muscle: Double]] {
        guard weeks >= 2 else { return [start] }
        var plan: [[Muscle: Double]] = [start]
        for _ in 1..<(weeks - 1) {
            var next: [Muscle: Double] = [:]
            for (muscle, sets) in plan[plan.count - 1] {
                let raised = sets + increment
                next[muscle] = min(raised, ceiling[muscle] ?? raised)
            }
            plan.append(next)
        }
        var deload: [Muscle: Double] = [:]
        for (muscle, sets) in plan[plan.count - 1] {
            deload[muscle] = sets * deloadFactor
        }
        plan.append(deload)
        return plan
    }

    /// Suggest a deload when volume has reached its ceiling or performance has declined two sessions running.
    public static func shouldDeload(recent: [SessionFeedback], atCeiling: Bool) -> Bool {
        if atCeiling { return true }
        let lastTwo = recent.suffix(2)
        return lastTwo.count == 2 && lastTwo.allSatisfy { $0.performance == .declined }
    }

    /// Next week's sets for one muscle: +increment while recovering well, hold when sore or flat, never above the ceiling.
    public static func nextWeekSets(current: Double, feedback: SessionFeedback, increment: Double = 1, ceiling: Double) -> Double {
        if feedback.performance == .declined || feedback.soreness >= 2 { return min(current, ceiling) }
        return min(current + increment, ceiling)
    }
}
