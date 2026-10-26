import Foundation

public enum Sex: String, Sendable {
    case male, female
}

/// Default activity multipliers from the brief (§9.3).
public enum ActivityLevel: Double, CaseIterable, Sendable {
    case sedentary = 1.2
    case light = 1.375
    case moderate = 1.55
    case active = 1.725
    case veryActive = 1.9
}

public enum BMR {
    /// Mifflin-St Jeor: 10*kg + 6.25*cm - 5*age + 5 (male) or - 161 (female).
    public static func mifflinStJeor(weightKg: Double, heightCm: Double, ageYears: Double, sex: Sex) -> Double {
        10 * weightKg + 6.25 * heightCm - 5 * ageYears + (sex == .male ? 5 : -161)
    }

    /// Katch-McArdle: 370 + 21.6 * lean body mass (kg). Use when body fat is known.
    public static func katchMcArdle(leanBodyMassKg: Double) -> Double {
        370 + 21.6 * leanBodyMassKg
    }
}

public enum Energy {
    /// Common heuristic for the energy content of one kg of body-weight change. Configurable by callers.
    public static let kcalPerKgBodyWeight = 7700.0
}

/// kcal ~= 4P + 4C + 9F + 7*alcohol_g (brief §9.3). Used to sanity-check labels and OCR.
public enum EnergyCheck {
    public static func kcal(proteinG: Double, carbsG: Double, fatG: Double, alcoholG: Double = 0) -> Double {
        4 * proteinG + 4 * carbsG + 9 * fatG + 7 * alcoholG
    }

    /// |computed - label| / label, or nil when the label has no energy to compare against.
    public static func mismatchFraction(
        labelKcal: Double,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        alcoholG: Double = 0
    ) -> Double? {
        guard labelKcal > 0 else { return nil }
        let computed = kcal(proteinG: proteinG, carbsG: carbsG, fatG: fatG, alcoholG: alcoholG)
        return abs(computed - labelKcal) / labelKcal
    }

    /// The brief flags anything more than 10% off.
    public static func isConsistent(
        labelKcal: Double,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        alcoholG: Double = 0,
        tolerance: Double = 0.10
    ) -> Bool {
        guard let mismatch = mismatchFraction(
            labelKcal: labelKcal, proteinG: proteinG, carbsG: carbsG, fatG: fatG, alcoholG: alcoholG
        ) else { return false }
        return mismatch <= tolerance
    }
}
