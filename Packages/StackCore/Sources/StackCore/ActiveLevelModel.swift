import Foundation

public struct DoseEvent: Equatable, Sendable {
    public let time: Date
    public let amount: Double

    public init(time: Date, amount: Double) {
        self.time = time
        self.amount = amount
    }
}

/// Illustrative one-compartment model of how much of a compound is still "active" (brief STK-10).
/// The result is a relative amount, not a blood concentration, and must be labeled that way in the UI.
/// With no published or user-entered half-life the model refuses to produce a curve (returns nil).
public enum ActiveLevelModel {
    /// - Parameters:
    ///   - halfLifeHours: elimination half-life; nil or non-positive disables the model.
    ///   - absorptionRatePerHour: first-order absorption rate k_a; nil means instant absorption.
    public static func level(
        at time: Date,
        doses: [DoseEvent],
        halfLifeHours: Double?,
        absorptionRatePerHour: Double? = nil
    ) -> Double? {
        guard let halfLife = halfLifeHours, halfLife > 0 else { return nil }
        let ke = log(2.0) / halfLife
        var total = 0.0
        for dose in doses {
            let hours = time.timeIntervalSince(dose.time) / 3600
            if hours < 0 { continue }
            total += dose.amount * contribution(hours: hours, ke: ke, ka: absorptionRatePerHour)
        }
        return total
    }

    /// How much higher the level is at steady state than after a single dose, for dosing every
    /// `intervalHours`: R = 1 / (1 - 0.5^(tau / t_half)).
    public static func accumulationFactor(intervalHours: Double, halfLifeHours: Double?) -> Double? {
        guard let halfLife = halfLifeHours, halfLife > 0, intervalHours > 0 else { return nil }
        return 1 / (1 - pow(0.5, intervalHours / halfLife))
    }

    private static func contribution(hours: Double, ke: Double, ka: Double?) -> Double {
        guard let ka = ka, ka > 0 else { return exp(-ke * hours) }
        if abs(ka - ke) < 1e-9 * ke {
            return ke * hours * exp(-ke * hours)
        }
        return ka / (ka - ke) * (exp(-ke * hours) - exp(-ka * hours))
    }
}
