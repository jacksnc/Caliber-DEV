//
//  SavedMeal.swift
//  Caliber (DEV)
//

import Foundation
import SwiftData

/// A reusable named combination of foods (e.g. "My Usual Breakfast") that can
/// be logged all at once from the Food Library's "My Meals" folder.
@Model
final class SavedMeal {
  var id: UUID
  var name: String
  /// Number of servings in this whole batch. Existing saved meals remain one complete meal.
  var servings: Double = 1
  /// Optional measured cooked batch weight. Never inferred from the ingredients.
  var cookedYieldGrams: Double? = nil
  /// Optional measured raw batch weight, separate from the cooked portion basis.
  var rawBatchGrams: Double? = nil

  @Relationship(deleteRule: .cascade, inverse: \SavedMealItem.savedMeal)
  var items: [SavedMealItem] = []

  init(
    name: String, servings: Double = 1, cookedYieldGrams: Double? = nil,
    rawBatchGrams: Double? = nil
  ) {
    self.id = UUID()
    self.name = name
    self.servings = servings
    self.cookedYieldGrams = cookedYieldGrams
    self.rawBatchGrams = rawBatchGrams
  }
}
