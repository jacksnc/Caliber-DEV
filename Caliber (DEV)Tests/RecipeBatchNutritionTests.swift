import Foundation
import Testing

@testable import Caliber__DEV_

@MainActor
private func recipeMathIngredients() -> [RecipeNutritionIngredient] {
  [
    RecipeNutritionIngredient(
      totals: MacroTotals(calories: 100, protein: 10, carbs: 5, fat: 2), quantity: 2),
    RecipeNutritionIngredient(
      totals: MacroTotals(calories: 50, protein: 1, carbs: 10, fat: 0.5), quantity: 3),
  ]
}

@MainActor @Test func recipeBatchGoldenMeasuredYieldAndServingsHaveTheSamePortion() throws {
  let batch = try RecipeBatchNutrition(
    ingredients: recipeMathIngredients(), servings: 4, cookedYieldGrams: 500, rawBatchGrams: 600)
  #expect(batch.totals == MacroTotals(calories: 350, protein: 23, carbs: 40, fat: 5.5))
  #expect(batch.servings == 4)
  #expect(batch.cookedYieldGrams == 500)
  #expect(batch.rawBatchGrams == 600)
  #expect(batch.rawToCookedFactor == 5.0 / 6.0)
  let expected = MacroTotals(calories: 87.5, protein: 5.75, carbs: 10, fat: 1.375)
  #expect(try batch.portion(amount: 1, unit: .servings) == expected)
  #expect(try batch.portion(amount: 125, unit: .cookedGrams) == expected)
  #expect(try batch.batchFraction(amount: 1, unit: .servings) == 0.25)
  #expect(try batch.batchFraction(amount: 125, unit: .cookedGrams) == 0.25)
  #expect(try batch.portion(amount: 4, unit: .servings) == batch.totals)
  #expect(try batch.portion(amount: 500, unit: .cookedGrams) == batch.totals)
}

@MainActor @Test func recipeBatchPreservesFractionalIngredientsServingsAndLargerPortions() throws {
  let batch = try RecipeBatchNutrition(
    ingredients: [
      RecipeNutritionIngredient(
        totals: MacroTotals(calories: 101.5, protein: 10.25, carbs: 7.75, fat: 1.5), quantity: 1.5),
      RecipeNutritionIngredient(
        totals: MacroTotals(calories: 20.25, protein: 0, carbs: 2.125, fat: 0.125), quantity: 0.25),
    ], servings: 2.5, cookedYieldGrams: 175.5)
  #expect(
    batch.totals == MacroTotals(calories: 157.3125, protein: 15.375, carbs: 12.15625, fat: 2.28125))
  #expect(try batch.portion(amount: 0.625, unit: .servings) == batch.totals.scaled(by: 0.25))
  #expect(try batch.portion(amount: 43.875, unit: .cookedGrams) == batch.totals.scaled(by: 0.25))
  #expect(try batch.portion(amount: 5, unit: .servings) == batch.totals.scaled(by: 2))
  #expect(try batch.portion(amount: 351, unit: .cookedGrams) == batch.totals.scaled(by: 2))
}

@MainActor @Test func recipeBatchNeverInfersCookedWeightRawWeightOrNutrientRetention() throws {
  let plain = try RecipeBatchNutrition(ingredients: recipeMathIngredients(), servings: 4)
  let rawOnly = try RecipeBatchNutrition(
    ingredients: recipeMathIngredients(), servings: 4, rawBatchGrams: 600)
  let cookedOnly = try RecipeBatchNutrition(
    ingredients: recipeMathIngredients(), servings: 4, cookedYieldGrams: 500)
  #expect(plain.rawToCookedFactor == nil)
  #expect(rawOnly.rawToCookedFactor == nil)
  #expect(cookedOnly.rawToCookedFactor == nil)
  #expect(plain.cookedYieldGrams == nil)
  #expect(rawOnly.cookedYieldGrams == nil)
  #expect(cookedOnly.rawBatchGrams == nil)
  #expect(plain.totals == rawOnly.totals && rawOnly.totals == cookedOnly.totals)
  for batch in [plain, rawOnly] {
    #expect(throws: RecipeBatchNutritionError.missingCookedYield) {
      try batch.batchFraction(amount: 125, unit: .cookedGrams)
    }
    #expect(throws: RecipeBatchNutritionError.missingCookedYield) {
      try batch.portion(amount: 125, unit: .cookedGrams)
    }
    #expect(try batch.portion(amount: 1, unit: .servings).calories == 87.5)
  }
  #expect(try cookedOnly.portion(amount: 125, unit: .cookedGrams).calories == 87.5)
  let increasedYield = try RecipeBatchNutrition(
    ingredients: recipeMathIngredients(), servings: 4, cookedYieldGrams: 900, rawBatchGrams: 600)
  #expect(increasedYield.rawToCookedFactor == 1.5)
  #expect(increasedYield.totals == plain.totals)
}

@MainActor @Test(arguments: [0.0, -1.0, Double.nan, Double.infinity, -Double.infinity])
func recipeBatchRejectsInvalidIngredientQuantitiesAndMeasuredMetadata(_ value: Double) {
  #expect(throws: RecipeBatchNutritionError.invalidIngredients) {
    try RecipeBatchNutrition(
      ingredients: [RecipeNutritionIngredient(totals: MacroTotals(), quantity: value)], servings: 1)
  }
  #expect(throws: RecipeBatchNutritionError.invalidMetadata) {
    try RecipeBatchNutrition(ingredients: recipeMathIngredients(), servings: value)
  }
  #expect(throws: RecipeBatchNutritionError.invalidMetadata) {
    try RecipeBatchNutrition(
      ingredients: recipeMathIngredients(), servings: 4, cookedYieldGrams: value)
  }
  #expect(throws: RecipeBatchNutritionError.invalidMetadata) {
    try RecipeBatchNutrition(
      ingredients: recipeMathIngredients(), servings: 4, rawBatchGrams: value)
  }
}

@MainActor @Test(arguments: [-0.1, Double.nan, Double.infinity, -Double.infinity])
func recipeBatchRejectsIncompleteOrInvalidNutritionInEveryNutrient(_ value: Double) {
  let invalid = [
    MacroTotals(calories: value, protein: 1, carbs: 1, fat: 1),
    MacroTotals(calories: 1, protein: value, carbs: 1, fat: 1),
    MacroTotals(calories: 1, protein: 1, carbs: value, fat: 1),
    MacroTotals(calories: 1, protein: 1, carbs: 1, fat: value),
  ]
  for totals in invalid {
    #expect(throws: RecipeBatchNutritionError.invalidIngredients) {
      try RecipeBatchNutrition(
        ingredients: [RecipeNutritionIngredient(totals: totals, quantity: 1)], servings: 1)
    }
  }
}

@MainActor @Test func recipeBatchIngredientBoundsAndExplicitZeroNutritionRemainDistinct() throws {
  #expect(throws: RecipeBatchNutritionError.invalidIngredients) {
    try RecipeBatchNutrition(ingredients: [], servings: 1)
  }
  let water = RecipeNutritionIngredient(totals: MacroTotals(), quantity: 1)
  #expect(throws: RecipeBatchNutritionError.invalidIngredients) {
    try RecipeBatchNutrition(ingredients: Array(repeating: water, count: 251), servings: 1)
  }
  let zero = try RecipeBatchNutrition(
    ingredients: Array(repeating: water, count: 250), servings: 4, cookedYieldGrams: 1_000)
  #expect(zero.totals == MacroTotals())
  #expect(try zero.portion(amount: 250, unit: .cookedGrams) == MacroTotals())
  #expect(try zero.portion(amount: 1, unit: .servings) == MacroTotals())
}

@MainActor @Test(arguments: [0.0, -1.0, Double.nan, Double.infinity, -Double.infinity])
func recipeBatchRejectsInvalidPortionsForBothUnits(_ amount: Double) throws {
  let batch = try RecipeBatchNutrition(
    ingredients: recipeMathIngredients(), servings: 4, cookedYieldGrams: 500)
  for unit in RecipePortionUnit.allCases {
    #expect(throws: RecipeBatchNutritionError.invalidPortion) {
      try batch.batchFraction(amount: amount, unit: unit)
    }
    #expect(throws: RecipeBatchNutritionError.invalidPortion) {
      try batch.portion(amount: amount, unit: unit)
    }
  }
}

@MainActor @Test func recipeBatchRejectsIngredientAggregateAndPortionOverflow() throws {
  let enormous = RecipeNutritionIngredient(
    totals: MacroTotals(calories: .greatestFiniteMagnitude), quantity: 2)
  #expect(throws: RecipeBatchNutritionError.unrepresentableResult) {
    try RecipeBatchNutrition(ingredients: [enormous], servings: 1)
  }
  let large = RecipeNutritionIngredient(
    totals: MacroTotals(calories: .greatestFiniteMagnitude), quantity: 1)
  #expect(throws: RecipeBatchNutritionError.unrepresentableResult) {
    try RecipeBatchNutrition(ingredients: [large, large], servings: 1)
  }
  let batch = try RecipeBatchNutrition(ingredients: [large], servings: 1, cookedYieldGrams: 1)
  for unit in RecipePortionUnit.allCases {
    #expect(throws: RecipeBatchNutritionError.unrepresentableResult) {
      try batch.portion(amount: 2, unit: unit)
    }
  }
}

@MainActor @Test func recipeBatchRejectsRatioFactorAndNutrientUnderflow() throws {
  let tiny = RecipeNutritionIngredient(
    totals: MacroTotals(calories: .leastNonzeroMagnitude), quantity: 0.5)
  #expect(throws: RecipeBatchNutritionError.unrepresentableResult) {
    try RecipeBatchNutrition(ingredients: [tiny], servings: 1)
  }
  for (cooked, raw) in [
    (Double.leastNonzeroMagnitude, Double.greatestFiniteMagnitude),
    (Double.greatestFiniteMagnitude, Double.leastNonzeroMagnitude),
  ] {
    #expect(throws: RecipeBatchNutritionError.unrepresentableResult) {
      try RecipeBatchNutrition(
        ingredients: recipeMathIngredients(), servings: 4, cookedYieldGrams: cooked,
        rawBatchGrams: raw)
    }
  }
  let largeDenominator = try RecipeBatchNutrition(
    ingredients: recipeMathIngredients(), servings: .greatestFiniteMagnitude,
    cookedYieldGrams: .greatestFiniteMagnitude)
  let smallDenominator = try RecipeBatchNutrition(
    ingredients: recipeMathIngredients(), servings: .leastNonzeroMagnitude,
    cookedYieldGrams: .leastNonzeroMagnitude)
  for unit in RecipePortionUnit.allCases {
    #expect(throws: RecipeBatchNutritionError.unrepresentableResult) {
      try largeDenominator.batchFraction(amount: .leastNonzeroMagnitude, unit: unit)
    }
    #expect(throws: RecipeBatchNutritionError.unrepresentableResult) {
      try smallDenominator.batchFraction(amount: .greatestFiniteMagnitude, unit: unit)
    }
  }
  let tinyNutrients = try RecipeBatchNutrition(
    ingredients: [
      RecipeNutritionIngredient(totals: MacroTotals(calories: .leastNonzeroMagnitude), quantity: 1)
    ], servings: 2)
  #expect(throws: RecipeBatchNutritionError.unrepresentableResult) {
    try tinyNutrients.portion(amount: 1, unit: .servings)
  }
}

@MainActor @Test func recipeBatchPortionUnitsAndErrorsArePlainAndStable() {
  #expect(RecipePortionUnit.allCases.map(\.id) == ["servings", "cookedGrams"])
  #expect(RecipePortionUnit.allCases.map(\.displayName) == ["Servings", "Cooked grams"])
  for error in [
    RecipeBatchNutritionError.invalidIngredients, .invalidMetadata, .invalidPortion,
    .missingCookedYield, .unrepresentableResult,
  ] {
    #expect(!error.localizedDescription.isEmpty)
    #expect(!error.localizedDescription.contains("/"))
  }
}
