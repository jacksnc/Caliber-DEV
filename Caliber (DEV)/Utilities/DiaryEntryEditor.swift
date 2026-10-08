import Foundation
import SwiftData

/// Saves a diary edit without changing a saved food, a menu item, or another log.
@MainActor
enum DiaryEntryEditor {
    enum ValidationError: LocalizedError {
        case invalidInput

        var errorDescription: String? {
            "Enter a food name, nonnegative nutrition values, and a quantity greater than zero."
        }
    }

    static func save(
        entry: DiaryEntry,
        name: String,
        totals: MacroTotals,
        quantity: Double,
        mealType: MealType,
        date: Date,
        in context: ModelContext,
        // Tests can simulate a disk failure; the app uses SwiftData's normal save.
        persist: (ModelContext) throws -> Void = { try $0.save() }
    ) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let macros = [totals.calories, totals.protein, totals.carbs, totals.fat]
        guard !trimmedName.isEmpty,
              quantity.isFinite, quantity > 0,
              macros.allSatisfy({ $0.isFinite && $0 >= 0 && ($0 * quantity).isFinite }) else {
            throw ValidationError.invalidInput
        }

        let originalFood = entry.foodItem
        let originalQuantity = entry.quantity
        let originalMealType = entry.mealType
        let originalDate = entry.date

        // Older logs can share their FoodItem with the library or another entry.
        // Always make a new copy so changing this log never changes those records.
        let editedFood = FoodItem(
            name: trimmedName,
            calories: totals.calories,
            proteinGrams: totals.protein,
            carbGrams: totals.carbs,
            fatGrams: totals.fat,
            servingDescription: originalFood?.servingDescription ?? "1 serving",
            sourceType: originalFood?.sourceType ?? .generic,
            isSavedToLibrary: false,
            menuItem: originalFood?.menuItem
        )
        context.insert(editedFood)
        entry.foodItem = editedFood
        entry.quantity = quantity
        entry.mealType = mealType
        entry.date = date

        do {
            try persist(context)
        } catch {
            // Undo only this attempted edit. A global rollback could discard
            // unrelated changes made elsewhere in the app's shared context.
            entry.foodItem = originalFood
            entry.quantity = originalQuantity
            entry.mealType = originalMealType
            entry.date = originalDate
            context.delete(editedFood)
            throw error
        }
    }
}
