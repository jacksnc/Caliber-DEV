import Foundation

public enum Goal: String, CaseIterable, Sendable {
    case cut, maintain, leanBulk, bulk, recomp
}

public struct TargetInputs: Sendable {
    public var sex: Sex
    public var ageYears: Double
    public var heightCm: Double
    public var weightKg: Double
    /// Body fat as a fraction (0.18 = 18%). When present and sensible, Katch-McArdle is used.
    public var bodyFatFraction: Double?
    public var activity: ActivityLevel
    /// Signed target change in kg per week: negative = lose, positive = gain.
    public var weeklyRateKg: Double
    /// Protein in g/kg. nil uses the default: 2.0 normally, 2.2 in a deficit.
    public var proteinPerKg: Double?
    /// Set only after an explicit clinician-override acknowledgement (brief §11.7).
    public var clinicianOverrideFloor: Bool

    public init(
        sex: Sex,
        ageYears: Double,
        heightCm: Double,
        weightKg: Double,
        bodyFatFraction: Double? = nil,
        activity: ActivityLevel,
        weeklyRateKg: Double,
        proteinPerKg: Double? = nil,
        clinicianOverrideFloor: Bool = false
    ) {
        self.sex = sex
        self.ageYears = ageYears
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.bodyFatFraction = bodyFatFraction
        self.activity = activity
        self.weeklyRateKg = weeklyRateKg
        self.proteinPerKg = proteinPerKg
        self.clinicianOverrideFloor = clinicianOverrideFloor
    }
}

public struct MacroTargets: Equatable, Sendable {
    public let calories: Double
    public let proteinG: Double
    public let fatG: Double
    public let carbsG: Double
    public let fiberG: Double
}

public enum TargetFlag: Equatable, Sendable {
    case calorieFloorApplied(floor: Double)
    case calorieFloorOverridden(floor: Double)
    case rateCapped(toKgPerWeek: Double)
    /// Protein plus the fat floor already use all the calories, so carbohydrate is zero.
    case macrosExceedCalories
}

public enum TargetBlock: Equatable, Sendable {
    case invalidInput
    case underEighteen
    /// BMI below 18.5: deficit goals are blocked and support resources should be shown.
    case underweightDeficit
}

public enum TargetOutcome: Equatable, Sendable {
    case blocked(TargetBlock)
    case ready(MacroTargets, tdee: Double, flags: [TargetFlag])
}

public struct CalorieGuardResult: Equatable, Sendable {
    public let allowed: Bool
    public let adjustedCalories: Double
    public let floor: Double
}

/// Target builder with the eating-disorder and body-image safety rails from brief §11.7.
public enum TargetBuilder {
    public static let maxLossFractionPerWeek = 0.01
    public static let underweightBMI = 18.5
    public static let minimumAdultAge = 18.0

    public static func calorieFloor(for sex: Sex) -> Double {
        sex == .male ? 1500 : 1200
    }

    public static func bmi(weightKg: Double, heightCm: Double) -> Double {
        let meters = heightCm / 100
        return weightKg / (meters * meters)
    }

    /// Checks a manually typed calorie target against the floor.
    public static func guardCalories(_ calories: Double, sex: Sex, clinicianOverride: Bool = false) -> CalorieGuardResult {
        let floor = calorieFloor(for: sex)
        if calories >= floor || clinicianOverride {
            return CalorieGuardResult(allowed: true, adjustedCalories: calories, floor: floor)
        }
        return CalorieGuardResult(allowed: false, adjustedCalories: floor, floor: floor)
    }

    public static func build(_ input: TargetInputs) -> TargetOutcome {
        guard input.weightKg > 0, input.heightCm > 0, input.ageYears > 0 else { return .blocked(.invalidInput) }
        guard input.ageYears >= minimumAdultAge else { return .blocked(.underEighteen) }

        var flags: [TargetFlag] = []
        var rate = input.weeklyRateKg

        if rate < 0 {
            if bmi(weightKg: input.weightKg, heightCm: input.heightCm) < underweightBMI {
                return .blocked(.underweightDeficit)
            }
            let cap = input.weightKg * maxLossFractionPerWeek
            if -rate > cap {
                rate = -cap
                flags.append(.rateCapped(toKgPerWeek: -cap))
            }
        }

        var bmr = BMR.mifflinStJeor(
            weightKg: input.weightKg, heightCm: input.heightCm, ageYears: input.ageYears, sex: input.sex
        )
        if let fraction = input.bodyFatFraction, fraction > 0, fraction < 1 {
            bmr = BMR.katchMcArdle(leanBodyMassKg: input.weightKg * (1 - fraction))
        }
        let tdee = bmr * input.activity.rawValue

        var calories = tdee + rate * Energy.kcalPerKgBodyWeight / 7
        let floor = calorieFloor(for: input.sex)
        if calories < floor {
            if input.clinicianOverrideFloor {
                flags.append(.calorieFloorOverridden(floor: floor))
            } else {
                calories = floor
                flags.append(.calorieFloorApplied(floor: floor))
            }
        }

        let proteinPerKg = input.proteinPerKg ?? (rate < 0 ? 2.2 : 2.0)
        let proteinG = proteinPerKg * input.weightKg
        let fatG = max(0.6 * input.weightKg, 0.20 * calories / 9)
        var carbsG = (calories - 4 * proteinG - 9 * fatG) / 4
        if carbsG < 0 {
            carbsG = 0
            flags.append(.macrosExceedCalories)
        }
        let fiberG = 14 * calories / 1000

        let targets = MacroTargets(calories: calories, proteinG: proteinG, fatG: fatG, carbsG: carbsG, fiberG: fiberG)
        return .ready(targets, tdee: tdee, flags: flags)
    }
}
