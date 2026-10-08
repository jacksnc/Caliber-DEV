//
//  MacroCalculatorTests.swift
//  Caliber (DEV)Tests
//

import Foundation
import Testing
@testable import Caliber__DEV_

@MainActor
@Suite("MacroCalculator")
struct MacroCalculatorTests {

    private func makeEntry(
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        quantity: Double = 1,
        meal: MealType = .breakfast
    ) -> DiaryEntry {
        let food = FoodItem(
            name: "Test Food",
            calories: calories,
            proteinGrams: protein,
            carbGrams: carbs,
            fatGrams: fat,
            servingDescription: "1 serving"
        )
        return DiaryEntry(date: .now, mealType: meal, foodItem: food, quantity: quantity)
    }

    @Test("Totals are zero for an empty list of entries")
    func emptyEntriesProduceZeroTotals() {
        let totals = MacroCalculator.totals(for: [DiaryEntry]())
        #expect(totals == MacroTotals())
    }

    @Test("Totals sum macros across multiple entries")
    func totalsSumAcrossEntries() {
        let entries = [
            makeEntry(calories: 200, protein: 10, carbs: 20, fat: 5),
            makeEntry(calories: 300, protein: 25, carbs: 30, fat: 10)
        ]
        let totals = MacroCalculator.totals(for: entries)
        #expect(totals.calories == 500)
        #expect(totals.protein == 35)
        #expect(totals.carbs == 50)
        #expect(totals.fat == 15)
    }

    @Test("Quantity scales an entry's macros")
    func quantityScalesMacros() {
        let entry = makeEntry(calories: 100, protein: 10, carbs: 10, fat: 10, quantity: 2.5)
        #expect(entry.calories == 250)
        #expect(entry.protein == 25)
        #expect(entry.carbs == 25)
        #expect(entry.fat == 25)
    }

    @Test("Totals filtered by meal type only include that meal")
    func totalsFilteredByMealType() {
        let entries = [
            makeEntry(calories: 200, protein: 10, carbs: 20, fat: 5, meal: .breakfast),
            makeEntry(calories: 500, protein: 40, carbs: 50, fat: 20, meal: .dinner)
        ]
        let totals = MacroCalculator.totals(for: entries, mealType: .breakfast)
        #expect(totals.calories == 200)
        #expect(totals.protein == 10)
    }

    @Test("Totals sum macros across SavedMealItems, scaled by each item's quantity")
    func savedMealItemTotalsScaleByQuantity() {
        let food = FoodItem(name: "Test Food", calories: 100, proteinGrams: 10, carbGrams: 10, fatGrams: 5, servingDescription: "1 serving")
        let items = [
            SavedMealItem(foodItem: food, quantity: 2),
            SavedMealItem(foodItem: food, quantity: 1)
        ]
        let totals = MacroCalculator.totals(for: items)
        #expect(totals.calories == 300)
        #expect(totals.protein == 30)
        #expect(totals.carbs == 30)
        #expect(totals.fat == 15)
    }
}
