import Foundation
import SwiftData
import Testing
@testable import Caliber__DEV_

@MainActor
@Suite("Diary entry editing")
struct DiaryEntryEditorTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            FoodItem.self, DiaryEntry.self, Restaurant.self, MenuItem.self,
            MenuItemModifier.self, BuildableItemTemplate.self,
            BuildComponentCategory.self, BuildComponentOption.self,
            SavedMeal.self, SavedMealItem.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    private func makeFood(name: String = "Chicken") -> FoodItem {
        FoodItem(
            name: name, calories: 180, proteinGrams: 32.5,
            carbGrams: 0, fatGrams: 7.5, servingDescription: "4 oz",
            sourceType: .restaurantMenuItem, isSavedToLibrary: true
        )
    }

    @Test("Editing a log preserves catalog, saved-meal, and other diary nutrition")
    func editCreatesIndependentSnapshot() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let menu = MenuItem(
            name: "Chicken", baseCalories: 180, baseProtein: 32.5,
            baseCarbs: 0, baseFat: 7.5, category: .entree
        )
        let originalFood = makeFood()
        originalFood.menuItem = menu
        let originalDate = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = DiaryEntry(date: originalDate, mealType: .lunch, foodItem: originalFood, note: "Keep my note")
        let otherEntry = DiaryEntry(date: originalDate, mealType: .dinner, foodItem: originalFood, quantity: 2)
        let savedMealItem = SavedMealItem(foodItem: originalFood, quantity: 1)
        context.insert(menu)
        context.insert(originalFood)
        context.insert(entry)
        context.insert(otherEntry)
        context.insert(savedMealItem)
        try context.save()
        let originalID = entry.id
        let revisedDate = originalDate.addingTimeInterval(86_400)

        try DiaryEntryEditor.save(
            entry: entry, name: "My portion",
            totals: MacroTotals(calories: 200.5, protein: 30.25, carbs: 2.5, fat: 8.75),
            quantity: 1.5, mealType: .breakfast, date: revisedDate, in: context
        )

        #expect(entry.id == originalID)
        #expect(entry.foodItem?.id != originalFood.id)
        #expect(entry.foodItem?.isSavedToLibrary == false)
        #expect(entry.foodItem?.sourceType == .restaurantMenuItem)
        #expect(entry.foodItem?.menuItem?.id == menu.id)
        #expect(entry.foodItem?.servingDescription == "4 oz")
        #expect(entry.note == "Keep my note")
        #expect(entry.mealType == .breakfast)
        #expect(entry.date == revisedDate)
        #expect(entry.calories == 300.75)
        #expect(entry.protein == 45.375)
        #expect(entry.carbs == 3.75)
        #expect(entry.fat == 13.125)
        #expect(originalFood.name == "Chicken")
        #expect(originalFood.calories == 180)
        #expect(originalFood.isSavedToLibrary)
        #expect(otherEntry.calories == 360)
        #expect(savedMealItem.calories == 180)
        #expect(menu.baseCalories == 180)

        // Read with another context to verify the change really reached storage.
        let reloadedContext = ModelContext(container)
        let reloaded = try #require(reloadedContext.fetch(FetchDescriptor<DiaryEntry>()).first { $0.id == originalID })
        #expect(reloaded.calories == 300.75)
        #expect(reloaded.quantity == 1.5)
    }

    private enum SaveFailure: Error {
        case diskFull
    }

    @Test("A failed save restores this entry without discarding unrelated pending changes")
    func failedSaveRestoresOnlyThisEdit() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let food = makeFood()
        let otherFood = makeFood(name: "Unrelated food")
        let originalDate = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = DiaryEntry(date: originalDate, mealType: .lunch, foodItem: food, quantity: 2)
        context.insert(food)
        context.insert(otherFood)
        context.insert(entry)
        try context.save()
        otherFood.name = "An unrelated pending change"

        #expect(throws: SaveFailure.self) {
            try DiaryEntryEditor.save(
                entry: entry, name: "Should not be saved",
                totals: MacroTotals(calories: 90, protein: 16, carbs: 0, fat: 3.5),
                quantity: 0.5, mealType: .dinner,
                date: originalDate.addingTimeInterval(86_400), in: context,
                persist: { _ in throw SaveFailure.diskFull }
            )
        }

        #expect(entry.foodItem?.id == food.id)
        #expect(entry.quantity == 2)
        #expect(entry.mealType == .lunch)
        #expect(entry.date == originalDate)
        #expect(entry.calories == 360)
        #expect(otherFood.name == "An unrelated pending change")

        try context.save()
        let reloadedContext = ModelContext(container)
        let foods = try reloadedContext.fetch(FetchDescriptor<FoodItem>())
        #expect(foods.count == 2)
        #expect(foods.contains { $0.name == "An unrelated pending change" })
    }

    @Test("Invalid quantities are rejected before a diary entry is changed", arguments: [0.0, -1.0, Double.infinity, Double.nan])
    func rejectsInvalidQuantities(quantity: Double) throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let food = makeFood()
        let entry = DiaryEntry(date: .now, mealType: .lunch, foodItem: food)
        context.insert(food)
        context.insert(entry)

        #expect(throws: DiaryEntryEditor.ValidationError.self) {
            try DiaryEntryEditor.save(
                entry: entry, name: "Chicken",
                totals: MacroTotals(calories: 100, protein: 10, carbs: 0, fat: 5),
                quantity: quantity, mealType: .dinner, date: .now, in: context
            )
        }
        #expect(entry.foodItem?.id == food.id)
        #expect(entry.quantity == 1)
        #expect(entry.mealType == .lunch)
    }
}
