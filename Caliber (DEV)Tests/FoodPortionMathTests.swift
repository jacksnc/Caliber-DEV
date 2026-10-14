import Foundation
import Testing

@testable import Caliber__DEV_

@MainActor @Test func weightOuncesAndSourcePortionsScaleTheExplicitBasisOnce() throws {
  let ounces = try FoodPortionMath.resolve(value: 4, unit: .ounces, basisGrams: 100)
  #expect(ounces.grams == 113.3980925 && ounces.quantity == 1)
  let reference = FoodNutritionReference(
    id: "fixture", name: "Fictional food",
    totals: MacroTotals(calories: 85, protein: 0.73, carbs: 20.1, fat: 0.22),
    basisDescription: "100 g", basisGrams: 100, sourceLabel: "Fixture",
    sourceURL: URL(string: "https://example.invalid")!, attribution: "Fixture", sourceNote: "")
  #expect(abs(try reference.portionTotals(grams: ounces.grams).calories - 96.388378625) < 1e-10)
  let servings = try FoodPortionMath.resolve(value: 2.5, unit: .portions, basisGrams: 30)
  #expect(servings.grams == 75 && servings.quantity == 1)
  #expect(try FoodPortionMath.amount(grams: 75, unit: .portions, basisGrams: 30) == 2.5)
  let display = try FoodPortionMath.amount(grams: 150.25, unit: .ounces, basisGrams: 100)
  #expect(
    abs(try FoodPortionMath.resolve(value: display, unit: .ounces, basisGrams: 100).grams! - 150.25)
      < 1e-12)
}

@MainActor @Test func unknownMassCanOnlyUseTheOriginalPortionMultiplier() throws {
  #expect(
    try FoodPortionMath.resolve(value: 2.5, unit: .portions, basisGrams: nil)
      == ResolvedFoodPortion(grams: nil, quantity: 2.5))
  for unit in [FoodPortionUnit.grams, .ounces] {
    #expect(throws: FoodCatalogError.invalidPortion) {
      try FoodPortionMath.resolve(value: 100, unit: unit, basisGrams: nil)
    }
  }
}

@MainActor @Test(arguments: [0.0, -1.0, Double.infinity, Double.nan])
func invalidPortionsAndBasisNeverBecomeValidLogs(value: Double) {
  for unit in FoodPortionUnit.allCases {
    #expect(throws: FoodCatalogError.invalidPortion) {
      try FoodPortionMath.resolve(value: value, unit: unit, basisGrams: 100)
    }
    #expect(throws: FoodCatalogError.invalidPortion) {
      try FoodPortionMath.resolve(value: 1, unit: unit, basisGrams: value)
    }
    #expect(throws: FoodCatalogError.invalidPortion) {
      try FoodPortionMath.amount(grams: value, unit: unit, basisGrams: 100)
    }
  }
}

@MainActor @Test func portionOverflowUnderflowAndLocalizedInputAreExplicit() throws {
  #expect(throws: FoodCatalogError.invalidPortion) {
    try FoodPortionMath.resolve(value: .greatestFiniteMagnitude, unit: .ounces, basisGrams: 100)
  }
  #expect(throws: FoodCatalogError.invalidPortion) {
    try FoodPortionMath.resolve(
      value: .leastNonzeroMagnitude, unit: .portions, basisGrams: .leastNonzeroMagnitude)
  }
  let value = try #require(NutritionInput.quantity("4,5", locale: Locale(identifier: "de_DE")))
  #expect(
    try FoodPortionMath.resolve(value: value, unit: .ounces, basisGrams: 30).grams == 4.5
      * FoodPortionMath.gramsPerOunce)
}
