import Foundation

/// Complete nutrition for one ingredient basis, multiplied by the explicit quantity used.
struct RecipeNutritionIngredient {
  let totals: MacroTotals
  let quantity: Double
}

enum RecipePortionUnit: String, CaseIterable, Identifiable {
  case servings, cookedGrams

  var id: String { rawValue }
  var displayName: String {
    switch self {
    case .servings: "Servings"
    case .cookedGrams: "Cooked grams"
    }
  }
}

enum RecipeBatchNutritionError: LocalizedError, Equatable {
  case invalidIngredients
  case invalidMetadata
  case invalidPortion
  case missingCookedYield
  case unrepresentableResult

  var errorDescription: String? {
    switch self {
    case .invalidIngredients:
      "Add between 1 and 250 ingredients with complete nutrition and quantities greater than zero."
    case .invalidMetadata:
      "Enter servings and any measured batch weights as numbers greater than zero."
    case .invalidPortion:
      "Enter a portion greater than zero."
    case .missingCookedYield:
      "Add a measured cooked batch weight before logging grams."
    case .unrepresentableResult:
      "These quantities are too large or too small to calculate. Check the ingredients and weights."
    }
  }
}

/// Batch nutrients are the sum of ingredient quantity times its nutrition basis. Cooking
/// weights change portion allocation only; they never change nutrients or imply retention.
struct RecipeBatchNutrition {
  let totals: MacroTotals
  let servings: Double
  let cookedYieldGrams: Double?
  let rawBatchGrams: Double?

  /// Available only when both raw and cooked weights were explicitly measured.
  var rawToCookedFactor: Double? {
    guard let cookedYieldGrams, let rawBatchGrams else { return nil }
    return cookedYieldGrams / rawBatchGrams
  }

  init(
    ingredients: [RecipeNutritionIngredient], servings: Double,
    cookedYieldGrams: Double? = nil, rawBatchGrams: Double? = nil
  ) throws {
    guard (1...250).contains(ingredients.count),
      ingredients.allSatisfy({ ingredient in
        ingredient.totals.isValid && Self.positive(ingredient.quantity)
      })
    else { throw RecipeBatchNutritionError.invalidIngredients }
    guard Self.positive(servings),
      cookedYieldGrams.map(Self.positive) ?? true, rawBatchGrams.map(Self.positive) ?? true
    else { throw RecipeBatchNutritionError.invalidMetadata }
    if let cookedYieldGrams, let rawBatchGrams {
      guard Self.positive(cookedYieldGrams / rawBatchGrams) else {
        throw RecipeBatchNutritionError.unrepresentableResult
      }
    }
    var sum = MacroTotals()
    for ingredient in ingredients {
      let contribution = try Self.scale(ingredient.totals, by: ingredient.quantity)
      sum = MacroTotals(
        calories: sum.calories + contribution.calories,
        protein: sum.protein + contribution.protein,
        carbs: sum.carbs + contribution.carbs,
        fat: sum.fat + contribution.fat)
      guard sum.isValid else { throw RecipeBatchNutritionError.unrepresentableResult }
    }
    self.totals = sum
    self.servings = servings
    self.cookedYieldGrams = cookedYieldGrams
    self.rawBatchGrams = rawBatchGrams
  }

  func portion(amount: Double, unit: RecipePortionUnit) throws -> MacroTotals {
    try Self.scale(totals, by: batchFraction(amount: amount, unit: unit))
  }

  func batchFraction(amount: Double, unit: RecipePortionUnit) throws -> Double {
    guard Self.positive(amount) else { throw RecipeBatchNutritionError.invalidPortion }
    let denominator: Double
    switch unit {
    case .servings:
      denominator = servings
    case .cookedGrams:
      guard let cookedYieldGrams else { throw RecipeBatchNutritionError.missingCookedYield }
      denominator = cookedYieldGrams
    }
    let fraction = amount / denominator
    guard Self.positive(fraction) else { throw RecipeBatchNutritionError.unrepresentableResult }
    return fraction
  }

  private static func positive(_ value: Double) -> Bool {
    value.isFinite && value > 0
  }

  private static func scale(_ input: MacroTotals, by quantity: Double) throws -> MacroTotals {
    let baseline = [input.calories, input.protein, input.carbs, input.fat]
    let scaled = baseline.map { $0 * quantity }
    guard scaled.allSatisfy({ $0.isFinite && $0 >= 0 }),
      zip(baseline, scaled).allSatisfy({ $0.0 == 0 || $0.1 > 0 })
    else { throw RecipeBatchNutritionError.unrepresentableResult }
    return MacroTotals(calories: scaled[0], protein: scaled[1], carbs: scaled[2], fat: scaled[3])
  }
}
