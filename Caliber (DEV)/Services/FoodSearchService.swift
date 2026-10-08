//
//  FoodSearchService.swift
//  Caliber (DEV)
//

import Foundation

/// Abstracts "search for a generic food by name" so a real food database or
/// API can replace this later without touching any view code.
@MainActor
protocol FoodSearchService {
    func search(query: String) async throws -> [FoodItem]
}

/// Temporary in-memory implementation used until a real backend exists.
struct MockFoodSearchService: FoodSearchService {
    private let sampleFoods: [FoodItem] = [
        FoodItem(name: "Chicken Breast", calories: 165, proteinGrams: 31, carbGrams: 0, fatGrams: 3.6, servingDescription: "100g"),
        FoodItem(name: "Brown Rice", calories: 216, proteinGrams: 5, carbGrams: 45, fatGrams: 1.8, servingDescription: "1 cup cooked"),
        FoodItem(name: "Banana", calories: 105, proteinGrams: 1.3, carbGrams: 27, fatGrams: 0.4, servingDescription: "1 medium"),
        FoodItem(name: "Egg", calories: 78, proteinGrams: 6.3, carbGrams: 0.6, fatGrams: 5.3, servingDescription: "1 large")
    ]

    func search(query: String) async throws -> [FoodItem] {
        guard !query.isEmpty else { return sampleFoods }
        return sampleFoods.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}
