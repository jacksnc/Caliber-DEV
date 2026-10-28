import Foundation
import Testing

@testable import CaliberCore

@Suite struct GoalSetupPlanTests {
  private func input(goal: EnergyGoal = .maintain) -> EnergyTargetInput {
    EnergyTargetInput(
      weightKilograms: 80, heightCentimeters: 180, ageYears: 30,
      coefficient: .plusFive, activityMultiplier: 1.375,
      weeklyWeightChangePercent: goal == .maintain ? 0 : 0.5, goal: goal)
  }

  @Test func startingTargetsKeepTheExistingEnginePrecisionAndMethod() throws {
    let source = input()
    let expected = try EnergyTargetCalculator.estimate(source)
    let plan = try GoalSetupPlanner.make(input: source)
    #expect(plan.input == source)
    #expect(plan.targets.calories == expected.calorieTarget)
    #expect(plan.targets.carbohydrates == expected.carbohydrateGrams)
    #expect(plan.targets.protein == expected.proteinGrams)
    #expect(plan.targets.fat == expected.fatGrams)
    #expect(!plan.wasEdited && plan.targetWeightKilograms == nil)
    #expect(try GoalSetupPlanner.decode(GoalSetupPlanner.encode(plan)) == plan)
  }

  @Test func editedTargetsRemainExplicitAndRoundTripExactly() throws {
    let targets = GoalMacroTargets(
      calories: 2345.123456789, protein: 151.25, carbohydrates: 245.75, fat: 68.875)
    let plan = try GoalSetupPlanner.make(
      input: input(goal: .cut), targetWeightKilograms: 75, editedTargets: targets)
    #expect(plan.wasEdited && plan.targets == targets)
    #expect(plan.targetReferenceWeightKilograms == 80)
    #expect(try GoalSetupPlanner.decode(GoalSetupPlanner.encode(plan)) == plan)
  }

  @Test func originalSafetyRulesStillApplyBeforeManualOverrides() throws {
    var source = input(goal: .cut)
    source.ageYears = 17
    #expect(throws: EnergyTargetError.invalidAge) { try GoalSetupPlanner.make(input: source) }
    source.ageYears = 30
    source.weeklyWeightChangePercent = 1.01
    #expect(throws: EnergyTargetError.lossRateAboveLimit) {
      try GoalSetupPlanner.make(input: source)
    }
    source.weeklyWeightChangePercent = 0.5
    source.weightKilograms = 50
    #expect(throws: EnergyTargetError.deficitBlockedForLowBMI) {
      try GoalSetupPlanner.make(input: source)
    }
    #expect(throws: EnergyTargetError.belowCalorieFloor(minimum: 1500)) {
      try GoalSetupPlanner.make(
        input: input(),
        editedTargets: GoalMacroTargets(calories: 1499, protein: 100, carbohydrates: 100, fat: 40))
    }
  }

  @Test func targetWeightDirectionAndLowerBoundaryAreValidated() throws {
    for target in [0.0, -1, .infinity, .nan] {
      #expect(throws: GoalSetupError.invalidTargetWeight) {
        try GoalSetupPlanner.make(input: input(goal: .cut), targetWeightKilograms: target)
      }
    }
    #expect(throws: GoalSetupError.targetDirection) {
      try GoalSetupPlanner.make(input: input(goal: .cut), targetWeightKilograms: 81)
    }
    #expect(throws: GoalSetupError.targetDirection) {
      try GoalSetupPlanner.make(input: input(goal: .bulk), targetWeightKilograms: 75)
    }
    #expect(throws: GoalSetupError.targetBelowMinimumBMI) {
      try GoalSetupPlanner.make(input: input(goal: .cut), targetWeightKilograms: 50)
    }
  }

  @Test func reachingAnUnchangedTargetDoesNotInvalidateThePlan() throws {
    let original = try GoalSetupPlanner.make(input: input(goal: .cut), targetWeightKilograms: 75)
    var updatedInput = original.input
    updatedInput.weightKilograms = 74
    let updated = try GoalSetupPlanner.make(
      input: updatedInput, targetWeightKilograms: original.targetWeightKilograms,
      targetReferenceWeightKilograms: original.targetReferenceWeightKilograms)
    #expect(updated.targetWeightKilograms == 75)
    #expect(updated.targetReferenceWeightKilograms == 80)
    #expect(try GoalSetupPlanner.decode(GoalSetupPlanner.encode(updated)) == updated)
    // A newly chosen target is checked against the current entered weight.
    #expect(throws: GoalSetupError.targetDirection) {
      try GoalSetupPlanner.make(input: updatedInput, targetWeightKilograms: 76)
    }
  }

  @Test func invalidMacroValuesAndCorruptVersionsCannotBeLoaded() throws {
    for protein in [-1.0, .nan, .infinity, Double.greatestFiniteMagnitude] {
      #expect(throws: GoalSetupError.invalidMacros) {
        try GoalSetupPlanner.make(
          input: input(),
          editedTargets: GoalMacroTargets(
            calories: 2200, protein: protein, carbohydrates: 100, fat: 50))
      }
    }
    let plan = try GoalSetupPlanner.make(input: input())
    var json = try #require(
      JSONSerialization.jsonObject(with: GoalSetupPlanner.encode(plan)) as? [String: Any])
    json["version"] = 2
    let unsupported = try JSONSerialization.data(withJSONObject: json)
    #expect(throws: GoalSetupError.unsupportedPlan) { try GoalSetupPlanner.decode(unsupported) }
    json["version"] = 1
    var targets = try #require(json["targets"] as? [String: Any])
    targets["calories"] = 4000
    json["targets"] = targets
    let altered = try JSONSerialization.data(withJSONObject: json)
    #expect(throws: GoalSetupError.unsupportedPlan) { try GoalSetupPlanner.decode(altered) }
  }

  @Test(arguments: ["en_US", "de_DE", "fr_FR"])
  func editableNumbersAreUngroupedAndLossless(localeID: String) throws {
    let locale = Locale(identifier: localeID)
    for value in [
      0.0, 2450.25, 2345.123456789, 1e-308, 1.2345678901234567e20, Double.greatestFiniteMagnitude,
    ] {
      let text = NumericInputText.string(value, locale: locale)
      #expect(!text.lowercased().contains("e"))
      #expect(try QuantityParsing.nonnegative(text, locale: locale) == value)
    }
    #expect(NumericInputText.string(.infinity, locale: locale).isEmpty)
  }
}
