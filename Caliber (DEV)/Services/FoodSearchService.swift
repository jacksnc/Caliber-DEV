//
//  FoodSearchService.swift
//  Caliber (DEV)
//

import Foundation

/// Abstracts generic food search so bundled and future hosted sources can be
/// swapped without changing the diary's editable-food flow.
@MainActor
protocol FoodSearchService {
  func search(query: String) async throws -> [FoodItem]
}

/// Small deterministic fixture reserved for previews and isolated UI tests.
/// The shipping search uses BundledFoodSearchService's offline USDA catalog.
struct MockFoodSearchService: FoodSearchService {
  private let sampleFoods: [FoodItem] = [
    FoodItem(
      name: "Chicken Breast", calories: 165, proteinGrams: 31, carbGrams: 0, fatGrams: 3.6,
      servingDescription: "100g"),
    FoodItem(
      name: "Brown Rice", calories: 216, proteinGrams: 5, carbGrams: 45, fatGrams: 1.8,
      servingDescription: "1 cup cooked"),
    FoodItem(
      name: "Banana", calories: 105, proteinGrams: 1.3, carbGrams: 27, fatGrams: 0.4,
      servingDescription: "1 medium"),
    FoodItem(
      name: "Egg", calories: 78, proteinGrams: 6.3, carbGrams: 0.6, fatGrams: 5.3,
      servingDescription: "1 large"),
  ]

  func search(query: String) async throws -> [FoodItem] {
    guard !query.isEmpty else { return sampleFoods }
    return sampleFoods.filter { $0.name.localizedCaseInsensitiveContains(query) }
  }
}
