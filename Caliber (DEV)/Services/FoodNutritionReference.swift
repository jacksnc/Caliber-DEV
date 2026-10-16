import Foundation
import SwiftData

/// A read-only source value. Editing a diary copy never changes a source catalog.
struct FoodNutritionReference: Identifiable {
  let id: String
  let name: String
  let totals: MacroTotals
  let basisDescription: String
  let basisGrams: Double?
  let sourceLabel: String
  let sourceURL: URL
  let attribution: String
  let sourceNote: String
  var servings: [FoodCatalogServing] = []

  static func usda(_ entry: FoodCatalogEntry) -> Self {
    Self(
      id: entry.id, name: entry.name,
      totals: MacroTotals(
        calories: entry.nutritionPer100g.calories,
        protein: entry.nutritionPer100g.proteinGrams,
        carbs: entry.nutritionPer100g.carbGrams, fat: entry.nutritionPer100g.fatGrams),
      basisDescription: "100 g", basisGrams: 100,
      sourceLabel: "USDA FDC \(entry.fdcID)", sourceURL: entry.sourceURL,
      attribution: entry.attribution,
      sourceNote:
        entry.sourceType == .foundation
        ? "Use the preparation in the food name. USDA values describe the food, not an individual package."
        : "Historical USDA reference from 2018. Check the preparation and your current label; this is not a current restaurant menu.",
      servings: entry.servings
    )
  }

  func portionTotals(grams: Double?) throws -> MacroTotals {
    guard totals.isValid else { throw FoodCatalogError.invalidData }
    if let basisGrams {
      guard basisGrams.isFinite, basisGrams > 0, let grams, grams.isFinite, grams > 0 else {
        throw FoodCatalogError.invalidPortion
      }
      let factor = grams / basisGrams
      guard factor > 0 else { throw FoodCatalogError.invalidPortion }
      let result = totals.scaled(by: factor)
      guard result.isValid else { throw FoodCatalogError.invalidPortion }
      return result
    }
    guard grams == nil else { throw FoodCatalogError.invalidPortion }
    return totals
  }
}

@MainActor
enum ReferenceFoodLogger {
  @discardableResult
  static func log(
    reference: FoodNutritionReference, grams: Double?, quantity: Double = 1,
    override: MacroTotals? = nil, saveToLibrary: Bool = false,
    enteredPortionDescription: String? = nil,
    date: Date, meal: MealType, in context: ModelContext,
    persist: (ModelContext) throws -> Void = { try $0.save() }
  ) throws -> DiaryEntry {
    let baseline = try reference.portionTotals(grams: grams)
    let totals = override ?? baseline
    guard !reference.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      quantity.isFinite, quantity > 0, totals.isValid,
      totals.scaled(by: quantity).isValid, date.timeIntervalSinceReferenceDate.isFinite
    else { throw FoodCatalogError.invalidPortion }
    let weight =
      grams.map { "\(NutritionInput.format($0, locale: Locale(identifier: "en_US"))) g" }
      ?? reference.basisDescription
    let portion = enteredPortionDescription.map { weight + " (" + $0 + ")" } ?? weight
    let food = FoodItem(
      name: reference.name + (override == nil ? "" : " (edited)"),
      calories: totals.calories, proteinGrams: totals.protein,
      carbGrams: totals.carbs, fatGrams: totals.fat,
      servingDescription: portion + " · " + reference.sourceLabel
        + (override == nil ? "" : " · personal values"),
      isSavedToLibrary: saveToLibrary)
    let entry = DiaryEntry(date: date, mealType: meal, foodItem: food, quantity: quantity)
    context.insert(food)
    context.insert(entry)
    do {
      try persist(context)
      return entry
    } catch {
      // Remove only this attempted log, leaving unrelated pending edits available.
      context.delete(entry)
      context.delete(food)
      throw error
    }
  }
}
