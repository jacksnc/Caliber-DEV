import Foundation

/// The explicit daily goals a person reviews before saving. Display rounding
/// never changes these stored values.
public struct GoalMacroTargets: Codable, Equatable, Sendable {
  public var calories: Double
  public var protein: Double
  public var carbohydrates: Double
  public var fat: Double

  public init(calories: Double, protein: Double, carbohydrates: Double, fat: Double) {
    self.calories = calories
    self.protein = protein
    self.carbohydrates = carbohydrates
    self.fat = fat
  }
}

/// Saved locally with the profile, not in UserDefaults or an online service.
/// The input records how the starting estimate was obtained; edited goals stay
/// distinct from that estimate. This is not an adaptive nutrition program.
public struct GoalSetupPlan: Codable, Equatable, Sendable {
  public let version: Int
  public let input: EnergyTargetInput
  public let targetWeightKilograms: Double?
  /// The entered weight when this specific target was chosen. Reaching it does
  /// not invalidate the saved target when current calculation inputs change.
  public let targetReferenceWeightKilograms: Double?
  public let targets: GoalMacroTargets
  public let wasEdited: Bool
}

public enum GoalSetupError: Error, Equatable, Sendable {
  case invalidTargetWeight
  case targetDirection
  case targetBelowMinimumBMI
  case invalidMacros
  case unsupportedPlan
}

public enum GoalSetupPlanner {
  public static func make(
    input: EnergyTargetInput, targetWeightKilograms: Double? = nil,
    targetReferenceWeightKilograms: Double? = nil,
    editedTargets: GoalMacroTargets? = nil
  ) throws -> GoalSetupPlan {
    // The existing engine owns the equation, activity, floor, age and rate rules.
    let estimate = try EnergyTargetCalculator.estimate(input)
    let reference =
      targetWeightKilograms == nil ? nil : (targetReferenceWeightKilograms ?? input.weightKilograms)
    if let target = targetWeightKilograms {
      guard target.isFinite, target > 0, let reference, reference.isFinite, reference > 0 else {
        throw GoalSetupError.invalidTargetWeight
      }
      switch input.goal {
      case .cut:
        guard target < reference else { throw GoalSetupError.targetDirection }
        let meters = input.heightCentimeters / 100
        guard target / (meters * meters) >= 18.5 else {
          throw GoalSetupError.targetBelowMinimumBMI
        }
      case .leanBulk, .bulk:
        guard target > reference else { throw GoalSetupError.targetDirection }
      case .maintain, .recomp:
        // These goals have no directional weight target in this first setup.
        throw GoalSetupError.targetDirection
      }
    }
    let targets =
      editedTargets
      ?? GoalMacroTargets(
        calories: estimate.calorieTarget, protein: estimate.proteinGrams,
        carbohydrates: estimate.carbohydrateGrams, fat: estimate.fatGrams)
    try EnergyTargetCalculator.validateManualTarget(
      calories: targets.calories, coefficient: input.coefficient)
    guard
      [targets.calories, targets.protein, targets.carbohydrates, targets.fat]
        .allSatisfy({ $0.isFinite && $0 >= 0 }),
      (targets.protein * 4 + targets.carbohydrates * 4 + targets.fat * 9).isFinite
    else { throw GoalSetupError.invalidMacros }
    return GoalSetupPlan(
      version: 1, input: input, targetWeightKilograms: targetWeightKilograms,
      targetReferenceWeightKilograms: reference,
      targets: targets, wasEdited: editedTargets != nil)
  }

  /// Validate stored data too. An unsupported/corrupt setup must not overwrite
  /// the profile's existing daily goals or be silently interpreted as a new one.
  public static func decode(_ data: Data) throws -> GoalSetupPlan {
    let plan = try JSONDecoder().decode(GoalSetupPlan.self, from: data)
    guard plan.version == 1 else { throw GoalSetupError.unsupportedPlan }
    let checked = try make(
      input: plan.input, targetWeightKilograms: plan.targetWeightKilograms,
      targetReferenceWeightKilograms: plan.targetReferenceWeightKilograms,
      editedTargets: plan.wasEdited ? plan.targets : nil)
    guard checked == plan else { throw GoalSetupError.unsupportedPlan }
    return checked
  }

  public static func encode(_ plan: GoalSetupPlan) throws -> Data {
    let data = try JSONEncoder().encode(plan)
    _ = try decode(data)
    return data
  }
}
