import Foundation

/// Rep-based one-rep-max estimators (brief §9.3). Weights may be in any consistent unit.
public enum OneRepMaxFormula: String, CaseIterable, Sendable {
    case epley, brzycki, oConner, lombardi, mayhew, wathan, lander
}

public enum EstimateConfidence: Int, Comparable, Sendable {
    case low = 0
    case medium = 1
    case high = 2

    public static func < (lhs: EstimateConfidence, rhs: EstimateConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct OneRepMaxEstimate: Equatable, Sendable {
    public let value: Double
    public let confidence: EstimateConfidence
    /// Reps actually fed to the formula (reps + reps in reserve when RPE is supplied).
    public let effectiveReps: Double

    public init(value: Double, confidence: EstimateConfidence, effectiveReps: Double) {
        self.value = value
        self.confidence = confidence
        self.effectiveReps = effectiveReps
    }
}

public enum OneRepMax {
    /// Above this many effective reps no estimate is returned (every formula degrades long before).
    public static let maxSupportedReps: Double = 30

    /// Plain estimate. A single rep returns the weight itself. Returns nil for invalid input.
    public static func estimate(weight: Double, reps: Int, formula: OneRepMaxFormula = .epley) -> Double? {
        guard weight > 0, reps >= 1, Double(reps) <= maxSupportedReps else { return nil }
        if reps == 1 { return weight }
        return apply(formula, weight: weight, reps: Double(reps))
    }

    /// Estimate with optional RPE adjustment: effective reps = reps + RIR, where RIR = 10 - RPE.
    public static func estimate(
        weight: Double,
        reps: Int,
        rpe: Double?,
        formula: OneRepMaxFormula = .epley
    ) -> OneRepMaxEstimate? {
        guard weight > 0, reps >= 1 else { return nil }
        var rir = 0.0
        if let rpe = rpe {
            rir = min(max(10 - rpe, 0), 10)
        }
        let effective = Double(reps) + rir
        guard effective <= maxSupportedReps else { return nil }
        let value = effective <= 1 ? weight : apply(formula, weight: weight, reps: effective)
        return OneRepMaxEstimate(value: value, confidence: confidence(forEffectiveReps: effective), effectiveReps: effective)
    }

    /// Reliability tiers from the brief: high up to 10 reps, medium 11-12, low above 12.
    public static func confidence(forEffectiveReps reps: Double) -> EstimateConfidence {
        if reps <= 10 { return .high }
        if reps <= 12 { return .medium }
        return .low
    }

    /// Fraction of 1RM that `reps` reps corresponds to (e.g. 5 reps is about 0.86 with Epley).
    public static func fractionOfOneRepMax(reps: Int, formula: OneRepMaxFormula = .epley) -> Double? {
        guard let factor = estimate(weight: 1, reps: reps, formula: formula) else { return nil }
        return 1 / factor
    }

    /// Weight you can lift for `reps` given a known 1RM ("what should I lift for N reps").
    public static func weight(forReps reps: Int, oneRepMax: Double, formula: OneRepMaxFormula = .epley) -> Double? {
        guard oneRepMax > 0, let fraction = fractionOfOneRepMax(reps: reps, formula: formula) else { return nil }
        return oneRepMax * fraction
    }

    private static func apply(_ formula: OneRepMaxFormula, weight w: Double, reps r: Double) -> Double {
        switch formula {
        case .epley:
            return w * (1 + r / 30)
        case .brzycki:
            return w * 36 / (37 - r)
        case .oConner:
            return w * (1 + 0.025 * r)
        case .lombardi:
            return w * pow(r, 0.10)
        case .mayhew:
            return 100 * w / (52.2 + 41.9 * exp(-0.055 * r))
        case .wathan:
            return 100 * w / (48.8 + 53.8 * exp(-0.075 * r))
        case .lander:
            return 100 * w / (101.3 - 2.67123 * r)
        }
    }
}
