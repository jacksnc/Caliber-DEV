//
//  MacroCalculator.swift
//  Caliber (DEV)
//

import Foundation

/// A plain (non-SwiftData) value type for holding summed-up macro values.
struct MacroTotals: Equatable {
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
}

/// Pure calculation logic, kept separate from views and SwiftData so it's
/// easy to unit test without spinning up a ModelContainer.
enum MacroCalculator {
    static func totals(for entries: [DiaryEntry]) -> MacroTotals {
        entries.reduce(into: MacroTotals()) { totals, entry in
            totals.calories += entry.calories
            totals.protein += entry.protein
            totals.carbs += entry.carbs
            totals.fat += entry.fat
        }
    }

    static func totals(for entries: [DiaryEntry], mealType: MealType) -> MacroTotals {
        totals(for: entries.filter { $0.mealType == mealType })
    }

    static func totals(for items: [SavedMealItem]) -> MacroTotals {
        items.reduce(into: MacroTotals()) { totals, item in
            totals.calories += item.calories
            totals.protein += item.protein
            totals.carbs += item.carbs
            totals.fat += item.fat
        }
    }
}
