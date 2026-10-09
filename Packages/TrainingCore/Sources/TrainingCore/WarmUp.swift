import Foundation

public struct WarmUpTemplate: Equatable, Sendable {
    public struct Step: Equatable, Sendable {
        public let fraction: Double
        public let reps: Int

        public init(fraction: Double, reps: Int) {
            self.fraction = fraction
            self.reps = reps
        }
    }

    public let steps: [Step]

    public init(steps: [Step]) {
        self.steps = steps
    }

    /// Brief default ramp: 40% x 8, 60% x 5, 75% x 3, 90% x 1.
    public static let standard = WarmUpTemplate(steps: [
        Step(fraction: 0.40, reps: 8),
        Step(fraction: 0.60, reps: 5),
        Step(fraction: 0.75, reps: 3),
        Step(fraction: 0.90, reps: 1),
    ])
}

public struct WarmUpStep: Equatable, Sendable {
    /// Total bar weight in hundredths of the working unit (always loadable).
    public let weight: Int
    public let reps: Int
    public let fractionOfTop: Double

    public init(weight: Int, reps: Int, fractionOfTop: Double) {
        self.weight = weight
        self.reps = reps
        self.fractionOfTop = fractionOfTop
    }
}

public enum WarmUpGenerator {
    /// Builds a ramp toward `topWeight`. Every step is rounded to the nearest weight the plate
    /// inventory can actually load; steps that would land on the empty bar, at or above the top
    /// weight, or not above the previous step are dropped.
    public static func generate(
        topWeight: Int,
        bar: Int,
        inventory: [Plate],
        template: WarmUpTemplate = .standard
    ) -> [WarmUpStep] {
        guard topWeight > bar else { return [] }
        var steps: [WarmUpStep] = []
        for step in template.steps {
            let raw = Int((Double(topWeight) * step.fraction).rounded())
            guard let load = PlateCalculator.nearest(to: raw, bar: bar, inventory: inventory) else { continue }
            let weight = load.total
            guard weight > bar, weight < topWeight else { continue }
            if let last = steps.last, weight <= last.weight { continue }
            steps.append(WarmUpStep(weight: weight, reps: step.reps, fractionOfTop: step.fraction))
        }
        return steps
    }
}
