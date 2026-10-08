//
//  DiaryEntry.swift
//  Caliber (DEV)
//

import Foundation
import SwiftData

/// One logged food on one day, in one meal. `quantity` scales the food's
/// per-serving macros (e.g. 1.5 servings).
@Model
final class DiaryEntry {
    var id: UUID
    var date: Date
    var mealType: MealType = MealType.snack
    var foodItem: FoodItem?
    var quantity: Double
    var note: String?

    init(
        date: Date,
        mealType: MealType,
        foodItem: FoodItem,
        quantity: Double = 1.0,
        note: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.mealType = mealType
        self.foodItem = foodItem
        self.quantity = quantity
        self.note = note
    }

    // These scale the underlying food's per-serving macros by `quantity`,
    // so every screen that totals up entries reads from one place.
    var calories: Double { (foodItem?.calories ?? 0) * quantity }
    var protein: Double { (foodItem?.proteinGrams ?? 0) * quantity }
    var carbs: Double { (foodItem?.carbGrams ?? 0) * quantity }
    var fat: Double { (foodItem?.fatGrams ?? 0) * quantity }
}
