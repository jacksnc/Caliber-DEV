import CaliberCore
import Foundation

/// Screen-local text: editing or cancelling never changes the saved profile.
struct GoalSetupDraft {
  var age = ""
  var height = ""
  var weight = ""
  var targetWeight = ""
  var coefficient: EnergyEquationCoefficient?
  var activity = ActivityLevel.sedentary
  var goal = EnergyGoal.maintain
  var weeklyRate = 0.5
  var calories = ""
  var protein = ""
  var carbohydrates = ""
  var fat = ""
  var overridesEstimate = false
  private var weightKilograms: Double?
  private var targetKilograms: Double?
  private var targetReferenceKilograms: Double?
  private var heightCentimeters: Double?

  mutating func setWeight(_ text: String) {
    weight = text
    weightKilograms = nil
  }
  mutating func setTargetWeight(_ text: String) {
    targetWeight = text
    targetKilograms = nil
    targetReferenceKilograms = nil
  }
  mutating func chooseGoal(_ value: EnergyGoal) {
    if goal != value { setTargetWeight("") }
    goal = value
  }

  mutating func setHeight(_ text: String) {
    height = text
    heightCentimeters = nil
  }

  mutating func changeMass(from old: MassUnit, to new: MassUnit, locale: Locale) {
    if let value = weightKilograms
      ?? (try? EnteredMass(text: weight, unit: old, locale: locale).kilograms)
    {
      weightKilograms = value
      weight = NumericInputText.string(new.fromKilograms(value), locale: locale)
    }
    if let value = targetKilograms
      ?? (try? EnteredMass(text: targetWeight, unit: old, locale: locale).kilograms)
    {
      targetKilograms = value
      targetWeight = NumericInputText.string(new.fromKilograms(value), locale: locale)
    }
  }

  mutating func changeLength(from old: DistanceUnit, to new: DistanceUnit, locale: Locale) {
    if let value = try? resolvedHeight(length: old, locale: locale) {
      heightCentimeters = value
      height = NumericInputText.string(new == .centimeters ? value : value / 2.54, locale: locale)
    }
  }

  func validateBody(mass: MassUnit, length: DistanceUnit, locale: Locale) throws {
    let text = age.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let years = Int(text), String(years) == text, (18...120).contains(years) else {
      throw EnergyTargetError.invalidAge
    }
    let kilograms = try resolvedWeight(mass: mass, locale: locale)
    let cm = try resolvedHeight(length: length, locale: locale)
    guard kilograms.isFinite, kilograms > 0, cm.isFinite, cm > 0 else {
      throw EnergyTargetError.invalidMeasurement
    }
  }

  private func resolvedWeight(mass: MassUnit, locale: Locale) throws -> Double {
    if let weightKilograms { return weightKilograms }
    return try EnteredMass(text: weight, unit: mass, locale: locale).kilograms
  }

  private func resolvedHeight(length: DistanceUnit, locale: Locale) throws -> Double {
    if let heightCentimeters { return heightCentimeters }
    let value = try QuantityParsing.nonnegative(height, locale: locale)
    return length == .centimeters ? value : value * 2.54
  }

  func input(mass: MassUnit, length: DistanceUnit, locale: Locale) throws -> EnergyTargetInput {
    try validateBody(mass: mass, length: length, locale: locale)
    let years = Int(age.trimmingCharacters(in: .whitespacesAndNewlines))!
    guard let coefficient else { throw GoalSetupDraftError.chooseEquation }
    let kilograms = try resolvedWeight(mass: mass, locale: locale)
    let cm = try resolvedHeight(length: length, locale: locale)
    return EnergyTargetInput(
      weightKilograms: kilograms,
      heightCentimeters: cm,
      ageYears: years, coefficient: coefficient,
      activityMultiplier: activity.activityMultiplier,
      weeklyWeightChangePercent: goal == .maintain || goal == .recomp ? 0 : weeklyRate,
      goal: goal)
  }

  func plan(mass: MassUnit, length: DistanceUnit, locale: Locale) throws -> GoalSetupPlan {
    let input = try input(mass: mass, length: length, locale: locale)
    let hasTarget = !targetWeight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let target =
      hasTarget
      ? try
        (targetKilograms ?? EnteredMass(text: targetWeight, unit: mass, locale: locale).kilograms)
      : nil
    let edited =
      overridesEstimate
      ? GoalMacroTargets(
        calories: try QuantityParsing.nonnegative(calories, locale: locale),
        protein: try QuantityParsing.nonnegative(protein, locale: locale),
        carbohydrates: try QuantityParsing.nonnegative(carbohydrates, locale: locale),
        fat: try QuantityParsing.nonnegative(fat, locale: locale)) : nil
    return try GoalSetupPlanner.make(
      input: input, targetWeightKilograms: target,
      targetReferenceWeightKilograms: targetReferenceKilograms, editedTargets: edited)
  }

  mutating func showEstimate(_ plan: GoalSetupPlan, locale: Locale) {
    // Keep full precision until a person explicitly switches to editing the review.
    calories = NumericInputText.string(plan.targets.calories, locale: locale)
    protein = NumericInputText.string(plan.targets.protein, locale: locale)
    carbohydrates = NumericInputText.string(plan.targets.carbohydrates, locale: locale)
    fat = NumericInputText.string(plan.targets.fat, locale: locale)
  }

  static func loaded(
    profile: UserProfile?, plan: GoalSetupPlan?, mass: MassUnit, length: DistanceUnit,
    locale: Locale
  ) -> GoalSetupDraft {
    var draft = GoalSetupDraft()
    if let profile {
      draft.height = NumericInputText.string(
        length == .centimeters ? profile.heightInInches * 2.54 : profile.heightInInches,
        locale: locale)
      draft.weight = NumericInputText.string(
        mass == .pounds ? profile.startingWeight : profile.startingWeight * 0.45359237,
        locale: locale)
      draft.activity = profile.activityLevel
      draft.weightKilograms = profile.startingWeight * 0.45359237
      draft.heightCentimeters = profile.heightInInches * 2.54
    }
    if let plan {
      // Reopening the exact setup must not round-trip its measurements through
      // the legacy profile's pounds/inches display representation.
      draft.weightKilograms = plan.input.weightKilograms
      draft.heightCentimeters = plan.input.heightCentimeters
      draft.weight = NumericInputText.string(
        mass.fromKilograms(plan.input.weightKilograms), locale: locale)
      draft.height = NumericInputText.string(
        length == .centimeters ? plan.input.heightCentimeters : plan.input.heightCentimeters / 2.54,
        locale: locale)
      draft.targetKilograms = plan.targetWeightKilograms
      draft.targetReferenceKilograms = plan.targetReferenceWeightKilograms
      draft.age = String(plan.input.ageYears)
      draft.coefficient = plan.input.coefficient
      draft.goal = plan.input.goal
      draft.weeklyRate =
        plan.input.weeklyWeightChangePercent > 0 ? plan.input.weeklyWeightChangePercent : 0.5
      draft.overridesEstimate = plan.wasEdited
      draft.showEstimate(plan, locale: locale)
      if plan.wasEdited, let profile {
        draft.calories = NumericInputText.string(profile.dailyCalorieGoal, locale: locale)
        draft.protein = NumericInputText.string(profile.proteinGoal, locale: locale)
        draft.carbohydrates = NumericInputText.string(profile.carbGoal, locale: locale)
        draft.fat = NumericInputText.string(profile.fatGoal, locale: locale)
      }
      draft.targetWeight =
        plan.targetWeightKilograms.map {
          NumericInputText.string(mass.fromKilograms($0), locale: locale)
        } ?? ""
    }
    return draft
  }
}

enum GoalSetupDraftError: Error { case chooseEquation }
