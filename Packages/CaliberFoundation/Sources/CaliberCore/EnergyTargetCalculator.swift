import Foundation

/// The two coefficients used by the published Mifflin–St Jeor equation.
///
/// The app asks the user to choose explicitly. It never infers a coefficient
/// from a name, appearance, or gender identity.
public enum EnergyEquationCoefficient: String, Codable, CaseIterable, Sendable {
  case plusFive
  case minusOneHundredSixtyOne

  public var value: Double {
    switch self {
    case .plusFive: 5
    case .minusOneHundredSixtyOne: -161
    }
  }

  /// Product safety floors from the Caliber build brief.
  public var calorieFloor: Double {
    switch self {
    case .plusFive: 1_500
    case .minusOneHundredSixtyOne: 1_200
    }
  }
}

public enum EnergyGoal: String, Codable, CaseIterable, Sendable {
  case cut
  case maintain
  case leanBulk
  case bulk
  case recomp

  var direction: Double {
    switch self {
    case .cut: -1
    case .leanBulk, .bulk: 1
    case .maintain, .recomp: 0
    }
  }
}

public struct EnergyTargetInput: Codable, Equatable, Sendable {
  public var weightKilograms: Double
  public var heightCentimeters: Double
  public var ageYears: Int
  public var coefficient: EnergyEquationCoefficient
  public var activityMultiplier: Double
  /// A value of 0.5 means one half of one percent per week.
  public var weeklyWeightChangePercent: Double
  public var goal: EnergyGoal

  public init(
    weightKilograms: Double,
    heightCentimeters: Double,
    ageYears: Int,
    coefficient: EnergyEquationCoefficient,
    activityMultiplier: Double,
    weeklyWeightChangePercent: Double,
    goal: EnergyGoal
  ) {
    self.weightKilograms = weightKilograms
    self.heightCentimeters = heightCentimeters
    self.ageYears = ageYears
    self.coefficient = coefficient
    self.activityMultiplier = activityMultiplier
    self.weeklyWeightChangePercent = weeklyWeightChangePercent
    self.goal = goal
  }
}

public struct EnergyTargetEstimate: Equatable, Sendable {
  public let restingEnergy: Double
  public let maintenanceEnergy: Double
  public let unadjustedTarget: Double
  public let calorieTarget: Double
  public let proteinGrams: Double
  public let carbohydrateGrams: Double
  public let fatGrams: Double
  public let fiberGrams: Double
  public let bodyMassIndex: Double
  public let floorWasApplied: Bool
}

public enum EnergyTargetError: Error, Equatable, Sendable {
  case invalidAge
  case invalidMeasurement
  case invalidActivityMultiplier
  case invalidRate
  case lossRateAboveLimit
  case deficitBlockedForLowBMI
  case incompatibleMacroTargets
  case belowCalorieFloor(minimum: Double)
}

/// Pure, deterministic starting-target math. It does not diagnose a condition
/// or promise a particular rate of weight change.
public enum EnergyTargetCalculator {
  private static let energyPerKilogram = 7_700.0
  private static let maximumWeeklyLossPercent = 1.0

  public static func estimate(_ input: EnergyTargetInput) throws -> EnergyTargetEstimate {
    guard (18...120).contains(input.ageYears) else { throw EnergyTargetError.invalidAge }
    guard input.weightKilograms.isFinite, input.weightKilograms > 0,
      input.heightCentimeters.isFinite, input.heightCentimeters > 0
    else { throw EnergyTargetError.invalidMeasurement }
    guard input.activityMultiplier.isFinite, input.activityMultiplier >= 1,
      input.activityMultiplier <= 2.5
    else { throw EnergyTargetError.invalidActivityMultiplier }
    guard input.weeklyWeightChangePercent.isFinite, input.weeklyWeightChangePercent >= 0
    else { throw EnergyTargetError.invalidRate }
    if input.goal == .cut,
      input.weeklyWeightChangePercent > maximumWeeklyLossPercent
    {
      throw EnergyTargetError.lossRateAboveLimit
    }

    let heightMeters = input.heightCentimeters / 100
    let bmi = input.weightKilograms / (heightMeters * heightMeters)
    if input.goal == .cut, bmi < 18.5 {
      throw EnergyTargetError.deficitBlockedForLowBMI
    }

    let resting =
      10 * input.weightKilograms + 6.25 * input.heightCentimeters
      - 5 * Double(input.ageYears) + input.coefficient.value
    let maintenance = resting * input.activityMultiplier
    let weeklyChangeKilograms =
      input.weightKilograms * (input.weeklyWeightChangePercent / 100)
    let dailyAdjustment = weeklyChangeKilograms * energyPerKilogram / 7
    let rawTarget = maintenance + input.goal.direction * dailyAdjustment
    let target = max(rawTarget, input.coefficient.calorieFloor)

    // A balanced high-protein starting point from the build brief. These are
    // editable goals after calculation, not a prescribed diet.
    let proteinPerKilogram = input.goal == .cut ? 2.2 : 2.0
    let protein = proteinPerKilogram * input.weightKilograms
    let fat = max(0.6 * input.weightKilograms, target * 0.20 / 9)
    let remainingEnergy = target - protein * 4 - fat * 9
    guard remainingEnergy >= 0 else { throw EnergyTargetError.incompatibleMacroTargets }

    return EnergyTargetEstimate(
      restingEnergy: resting,
      maintenanceEnergy: maintenance,
      unadjustedTarget: rawTarget,
      calorieTarget: target,
      proteinGrams: protein,
      carbohydrateGrams: remainingEnergy / 4,
      fatGrams: fat,
      fiberGrams: target / 1_000 * 14,
      bodyMassIndex: bmi,
      floorWasApplied: target != rawTarget)
  }

  public static func validateManualTarget(
    calories: Double, coefficient: EnergyEquationCoefficient
  ) throws {
    guard calories.isFinite, calories > 0 else { throw EnergyTargetError.invalidMeasurement }
    guard calories >= coefficient.calorieFloor else {
      throw EnergyTargetError.belowCalorieFloor(minimum: coefficient.calorieFloor)
    }
  }
}
