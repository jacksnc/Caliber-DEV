import Foundation

/// A set the app prescribes for the next session.
public struct PrescribedSet: Equatable, Sendable {
    public let weight: Double
    public let reps: Int
    public let isAMRAP: Bool

    public init(weight: Double, reps: Int, isAMRAP: Bool = false) {
        self.weight = weight
        self.reps = reps
        self.isAMRAP = isAMRAP
    }
}

/// "Next time" suggestion with a plain-language reason (brief TRN-43).
public struct NextTime: Equatable, Sendable {
    public let weight: Double
    public let targetReps: Int
    public let reason: String

    public init(weight: Double, targetReps: Int, reason: String) {
        self.weight = weight
        self.targetReps = targetReps
        self.reason = reason
    }
}

// MARK: - (a) Linear

/// Add a fixed increment after every successful session; after repeated failures take a deload.
public struct LinearProgression: Equatable, Sendable {
    public struct State: Equatable, Sendable {
        public var weight: Double
        public var consecutiveFailures: Int

        public init(weight: Double, consecutiveFailures: Int = 0) {
            self.weight = weight
            self.consecutiveFailures = consecutiveFailures
        }
    }

    public struct Step: Equatable, Sendable {
        public let state: State
        public let reason: String
    }

    public var increment: Double
    public var failuresBeforeDeload: Int
    public var deloadFactor: Double
    public var rounding: LoadRounding

    public init(
        increment: Double = 2.5,
        failuresBeforeDeload: Int = 3,
        deloadFactor: Double = 0.9,
        rounding: LoadRounding = .none
    ) {
        self.increment = increment
        self.failuresBeforeDeload = failuresBeforeDeload
        self.deloadFactor = deloadFactor
        self.rounding = rounding
    }

    public func next(from state: State, completedAllReps: Bool) -> Step {
        if completedAllReps {
            let weight = rounding.round(state.weight + increment, direction: .nearest)
            return Step(
                state: State(weight: weight, consecutiveFailures: 0),
                reason: "Completed all reps: add \(formatNumber(increment)) to \(formatNumber(weight))"
            )
        }

        let failures = state.consecutiveFailures + 1
        if failures >= failuresBeforeDeload {
            let weight = rounding.round(state.weight * deloadFactor, direction: .nearest)
            return Step(
                state: State(weight: weight, consecutiveFailures: 0),
                reason: "\(failures) missed sessions in a row: deload to \(formatNumber(weight))"
            )
        }
        return Step(
            state: State(weight: state.weight, consecutiveFailures: failures),
            reason: "Missed reps (\(failures) of \(failuresBeforeDeload) before a deload): repeat \(formatNumber(state.weight))"
        )
    }
}

// MARK: - (b) Double progression

/// Climb the rep range at a fixed weight, then add load and start over at the bottom of the range.
public struct DoubleProgression: Equatable, Sendable {
    public var repRange: ClosedRange<Int>
    public var increment: Double
    public var rounding: LoadRounding

    public init(repRange: ClosedRange<Int>, increment: Double = 2.5, rounding: LoadRounding = .none) {
        self.repRange = repRange
        self.increment = increment
        self.rounding = rounding
    }

    /// - Parameter repsPerSet: reps achieved on each working set of the last session, at `weight`.
    public func next(weight: Double, repsPerSet: [Int]) -> NextTime {
        let low = repRange.lowerBound
        let high = repRange.upperBound
        guard let lowest = repsPerSet.min() else {
            return NextTime(weight: weight, targetReps: low, reason: "No sets logged: start at \(low) reps")
        }

        if lowest >= high {
            let heavier = rounding.round(weight + increment, direction: .nearest)
            return NextTime(
                weight: heavier,
                targetReps: low,
                reason: "Every set reached \(high) reps: add \(formatNumber(increment)) and restart at \(low)"
            )
        }
        if lowest < low {
            return NextTime(
                weight: weight,
                targetReps: low,
                reason: "A set fell below \(low) reps: hold \(formatNumber(weight)) and rebuild to \(low)"
            )
        }
        return NextTime(
            weight: weight,
            targetReps: lowest + 1,
            reason: "Lowest set was \(lowest): aim for \(lowest + 1) reps on every set at \(formatNumber(weight))"
        )
    }
}

// MARK: - (c) Percentage-of-training-max waves

public struct WaveSet: Equatable, Sendable {
    public let percent: Double
    public let reps: Int
    public let isAMRAP: Bool

    public init(percent: Double, reps: Int, isAMRAP: Bool = false) {
        self.percent = percent
        self.reps = reps
        self.isAMRAP = isAMRAP
    }
}

/// A generic, user-editable weekly wave. Percentages are plain data, not tied to any branded program.
public struct WaveTemplate: Equatable, Sendable {
    public let weeks: [[WaveSet]]
    /// Added to the training max after each full cycle.
    public let cycleIncrement: Double

    public init(weeks: [[WaveSet]], cycleIncrement: Double) {
        self.weeks = weeks
        self.cycleIncrement = cycleIncrement
    }

    /// Three loading weeks followed by a lighter week.
    public static let fourWeek = WaveTemplate(
        weeks: [
            [WaveSet(percent: 0.70, reps: 5), WaveSet(percent: 0.80, reps: 5), WaveSet(percent: 0.90, reps: 5, isAMRAP: true)],
            [WaveSet(percent: 0.75, reps: 3), WaveSet(percent: 0.85, reps: 3), WaveSet(percent: 0.95, reps: 3, isAMRAP: true)],
            [WaveSet(percent: 0.80, reps: 2), WaveSet(percent: 0.90, reps: 2), WaveSet(percent: 1.00, reps: 1, isAMRAP: true)],
            [WaveSet(percent: 0.60, reps: 5), WaveSet(percent: 0.65, reps: 5), WaveSet(percent: 0.70, reps: 5)],
        ],
        cycleIncrement: 5
    )
}

public enum WaveEngine {
    /// Sets for `week` (0-based; wraps around the template length).
    public static func prescription(
        trainingMax: Double,
        week: Int,
        template: WaveTemplate = .fourWeek,
        rounding: LoadRounding = .none
    ) -> [PrescribedSet] {
        guard trainingMax > 0, !template.weeks.isEmpty else { return [] }
        let count = template.weeks.count
        let index = ((week % count) + count) % count
        return template.weeks[index].map { set in
            PrescribedSet(
                weight: rounding.round(trainingMax * set.percent, direction: .nearest),
                reps: set.reps,
                isAMRAP: set.isAMRAP
            )
        }
    }

    public static func nextTrainingMax(_ trainingMax: Double, template: WaveTemplate = .fourWeek, rounding: LoadRounding = .none) -> Double {
        rounding.round(trainingMax + template.cycleIncrement, direction: .nearest)
    }
}

// MARK: - (d) RPE autoregulation

public enum RPEAutoregulation {
    /// Load for `targetReps` at `targetRPE` given a current 1RM estimate.
    public static func prescribe(
        oneRepMax: Double,
        targetReps: Int,
        targetRPE: Double,
        formula: OneRepMaxFormula = .epley,
        rounding: LoadRounding = .none
    ) -> PrescribedSet? {
        guard targetReps >= 1 else { return nil }
        let reserve = min(max(10 - targetRPE, 0), 10)
        guard let raw = OneRepMax.weight(
            forEffectiveReps: Double(targetReps) + reserve, oneRepMax: oneRepMax, formula: formula
        ) else { return nil }
        return PrescribedSet(weight: rounding.round(raw, direction: .nearest), reps: targetReps)
    }

    /// Re-estimates 1RM from the last set (RPE-adjusted) and prescribes the next target from it.
    public static func fromLastSet(
        weight: Double,
        reps: Int,
        rpe: Double,
        targetReps: Int,
        targetRPE: Double,
        formula: OneRepMaxFormula = .epley,
        rounding: LoadRounding = .none
    ) -> (estimatedOneRepMax: Double, next: PrescribedSet)? {
        guard let estimate = OneRepMax.estimate(weight: weight, reps: reps, rpe: rpe, formula: formula),
              let next = prescribe(
                oneRepMax: estimate.value, targetReps: targetReps, targetRPE: targetRPE, formula: formula, rounding: rounding
              )
        else { return nil }
        return (estimate.value, next)
    }
}

// MARK: - (e) Top set + back-off

public enum BackoffEngine {
    /// Back-off sets at `percent` below the top set (0.10 = 10% lighter).
    public static func sets(
        topWeight: Double,
        percent: Double = 0.10,
        count: Int,
        reps: Int,
        rounding: LoadRounding = .none
    ) -> [PrescribedSet] {
        guard topWeight > 0, count > 0, reps > 0, percent >= 0, percent < 1 else { return [] }
        let weight = rounding.round(topWeight * (1 - percent), direction: .nearest)
        return Array(repeating: PrescribedSet(weight: weight, reps: reps), count: count)
    }
}
