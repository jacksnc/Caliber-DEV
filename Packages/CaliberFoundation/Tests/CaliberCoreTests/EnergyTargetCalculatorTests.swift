import Testing

@testable import CaliberCore

@Test func mifflinGoldenVectorsAndActivityFactorAreExact() throws {
  let plusFive = try EnergyTargetCalculator.estimate(
    EnergyTargetInput(
      weightKilograms: 80, heightCentimeters: 180, ageYears: 30,
      coefficient: .plusFive, activityMultiplier: 1.55,
      weeklyWeightChangePercent: 0, goal: .maintain))
  #expect(plusFive.restingEnergy == 1_780)
  #expect(plusFive.maintenanceEnergy == 2_759)
  #expect(plusFive.calorieTarget == 2_759)

  let minusOneSixtyOne = try EnergyTargetCalculator.estimate(
    EnergyTargetInput(
      weightKilograms: 60, heightCentimeters: 165, ageYears: 30,
      coefficient: .minusOneHundredSixtyOne, activityMultiplier: 1.2,
      weeklyWeightChangePercent: 0, goal: .maintain))
  #expect(minusOneSixtyOne.restingEnergy == 1_320.25)
  #expect(minusOneSixtyOne.maintenanceEnergy == 1_584.3)
}

@Test func cutUsesRequestedRateAndMacroEnergyReconciles() throws {
  let result = try EnergyTargetCalculator.estimate(
    EnergyTargetInput(
      weightKilograms: 100, heightCentimeters: 190, ageYears: 30,
      coefficient: .plusFive, activityMultiplier: 1.55,
      weeklyWeightChangePercent: 0.5, goal: .cut))
  #expect(abs(result.unadjustedTarget - (3_165.875 - 550.0)) < 0.000_001)
  let macroCalories =
    result.proteinGrams * 4 + result.carbohydrateGrams * 4 + result.fatGrams * 9
  #expect(abs(result.calorieTarget - macroCalories) < 0.000_001)
  #expect(abs(result.proteinGrams - 220) < 0.000_001)
  #expect(result.fiberGrams == result.calorieTarget / 1_000 * 14)
}

@Test func safetyRailsBlockLowBMIAndExcessiveLossRate() {
  #expect(throws: EnergyTargetError.deficitBlockedForLowBMI) {
    try EnergyTargetCalculator.estimate(
      EnergyTargetInput(
        weightKilograms: 50, heightCentimeters: 180, ageYears: 30,
        coefficient: .plusFive, activityMultiplier: 1.2,
        weeklyWeightChangePercent: 0.5, goal: .cut))
  }
  #expect(throws: EnergyTargetError.lossRateAboveLimit) {
    try EnergyTargetCalculator.estimate(
      EnergyTargetInput(
        weightKilograms: 80, heightCentimeters: 180, ageYears: 30,
        coefficient: .plusFive, activityMultiplier: 1.2,
        weeklyWeightChangePercent: 1.01, goal: .cut))
  }
}

@Test func calorieFloorPreventsA900CalorieTargetAndManualSave() throws {
  let result = try EnergyTargetCalculator.estimate(
    EnergyTargetInput(
      weightKilograms: 40, heightCentimeters: 150, ageYears: 90,
      coefficient: .minusOneHundredSixtyOne, activityMultiplier: 1.0,
      weeklyWeightChangePercent: 0, goal: .maintain))
  #expect(result.unadjustedTarget < 1_200)
  #expect(result.calorieTarget == 1_200)
  #expect(result.floorWasApplied)
  #expect(throws: EnergyTargetError.belowCalorieFloor(minimum: 1_200)) {
    try EnergyTargetCalculator.validateManualTarget(
      calories: 900, coefficient: .minusOneHundredSixtyOne)
  }
}
