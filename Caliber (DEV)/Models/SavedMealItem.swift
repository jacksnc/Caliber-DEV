//
//  SavedMealItem.swift
//  Caliber (DEV)
//

import Foundation
import SwiftData

/// One food within a SavedMeal, with its own quantity — e.g. "2 Eggs" inside
/// "My Usual Breakfast".
@Model
final class SavedMealItem {
    var id: UUID
    var quantity: Double
    var foodItem: FoodItem?
    var savedMeal: SavedMeal?

    init(foodItem: FoodItem, quantity: Double = 1.0) {
        self.id = UUID()
        self.foodItem = foodItem
        self.quantity = quantity
    }

    var calories: Double { (foodItem?.calories ?? 0) * quantity }
    var protein: Double { (foodItem?.proteinGrams ?? 0) * quantity }
    var carbs: Double { (foodItem?.carbGrams ?? 0) * quantity }
    var fat: Double { (foodItem?.fatGrams ?? 0) * quantity }
}
