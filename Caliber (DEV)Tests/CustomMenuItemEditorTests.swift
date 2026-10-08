import Foundation
import SwiftData
import Testing
@testable import Caliber__DEV_

@MainActor
@Suite("Custom restaurant menu items")
struct CustomMenuItemEditorTests {
    private let originalTotals = MacroTotals(calories: 123.5, protein: 12.5, carbs: 7.25, fat: 3.75)

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            FoodItem.self, DiaryEntry.self, Restaurant.self, MenuItem.self,
            MenuItemModifier.self, BuildableItemTemplate.self,
            BuildComponentCategory.self, BuildComponentOption.self
        ])
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    private func makeFixture(custom: Bool = true) throws -> (
        container: ModelContainer, context: ModelContext, restaurant: Restaurant,
        item: MenuItem, food: FoodItem, entry: DiaryEntry
    ) {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let restaurant = Restaurant(name: "Test Restaurant")
        let item = MenuItem(
            name: "My Side", baseCalories: originalTotals.calories,
            baseProtein: originalTotals.protein, baseCarbs: originalTotals.carbs,
            baseFat: originalTotals.fat, category: .side, isCustom: custom
        )
        restaurant.menuItems = [item]
        let food = FoodItem(
            name: item.name, calories: item.baseCalories,
            proteinGrams: item.baseProtein, carbGrams: item.baseCarbs,
            fatGrams: item.baseFat, servingDescription: "1 item",
            sourceType: .restaurantMenuItem, menuItem: item
        )
        let entry = DiaryEntry(date: .now, mealType: .lunch, foodItem: food, quantity: 2)
        context.insert(restaurant)
        context.insert(food)
        context.insert(entry)
        try context.save()
        return (container, context, restaurant, item, food, entry)
    }

    @Test("Creating an item persists its trimmed name, category, custom flag, and restaurant")
    func createPersistsCustomItem() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let restaurant = Restaurant(name: "Test Restaurant")
        context.insert(restaurant)
        try context.save()

        let item = try CustomMenuItemEditor.save(
            restaurant: restaurant, name: "  Custom Entrée \n", category: .entree,
            totals: originalTotals, in: context
        )

        #expect(item.isCustom)
        #expect(item.name == "Custom Entrée")
        #expect(restaurant.menuItems.count == 1)
        let readContext = ModelContext(container)
        let stored = try #require(readContext.fetch(FetchDescriptor<MenuItem>()).first)
        #expect(stored.id == item.id)
        #expect(stored.name == "Custom Entrée")
        #expect(stored.isCustom)
        #expect(stored.category == .entree)
        #expect(stored.restaurant?.id == restaurant.id)
        #expect(stored.baseCalories == 123.5)
        #expect(stored.baseProtein == 12.5)
        #expect(stored.baseCarbs == 7.25)
        #expect(stored.baseFat == 3.75)
    }

    @Test("Editing updates the same custom row and leaves already logged nutrition unchanged")
    func editPreservesSnapshots() throws {
        let fixture = try makeFixture()
        let originalID = fixture.item.id
        let edited = MacroTotals(calories: 250.25, protein: 20.5, carbs: 25.25, fat: 10.5)

        let result = try CustomMenuItemEditor.save(
            item: fixture.item, restaurant: fixture.restaurant,
            name: "  Updated Entrée ", category: .entree, totals: edited, in: fixture.context
        )

        #expect(result.id == originalID)
        #expect(result.restaurant?.id == fixture.restaurant.id)
        #expect(fixture.restaurant.menuItems.count == 1)
        #expect(fixture.food.name == "My Side")
        #expect(fixture.food.calories == originalTotals.calories)
        #expect(fixture.food.menuItem?.id == originalID)
        #expect(fixture.entry.calories == 247)
        #expect(fixture.entry.protein == 25)
        #expect(fixture.entry.carbs == 14.5)
        #expect(fixture.entry.fat == 7.5)

        let readContext = ModelContext(fixture.container)
        let storedItems = try readContext.fetch(FetchDescriptor<MenuItem>())
        #expect(storedItems.count == 1)
        let stored = try #require(storedItems.first)
        #expect(stored.id == originalID)
        #expect(stored.name == "Updated Entrée")
        #expect(stored.category == .entree)
        #expect(stored.baseCalories == 250.25)
        #expect(stored.isCustom)
        let logged = try #require(readContext.fetch(FetchDescriptor<DiaryEntry>()).first)
        #expect(logged.calories == 247)
    }

    @Test("Deleting a custom item keeps logged foods and detaches their optional menu links")
    func deletePreservesSnapshots() throws {
        let fixture = try makeFixture()
        let originalEntryID = fixture.entry.id
        let originalFoodID = fixture.food.id
        try CustomMenuItemEditor.delete(item: fixture.item, in: fixture.context)

        #expect(fixture.restaurant.menuItems.isEmpty)
        #expect(fixture.food.menuItem == nil)
        #expect(fixture.entry.calories == 247)

        let readContext = ModelContext(fixture.container)
        #expect(try readContext.fetchCount(FetchDescriptor<MenuItem>()) == 0)
        #expect(try readContext.fetchCount(FetchDescriptor<FoodItem>()) == 1)
        #expect(try readContext.fetchCount(FetchDescriptor<DiaryEntry>()) == 1)
        let storedEntry = try #require(readContext.fetch(FetchDescriptor<DiaryEntry>()).first)
        #expect(storedEntry.id == originalEntryID)
        #expect(storedEntry.foodItem?.id == originalFoodID)
        #expect(storedEntry.foodItem?.menuItem == nil)
        #expect(storedEntry.foodItem?.sourceType == .restaurantMenuItem)
        #expect(storedEntry.foodItem?.name == "My Side")
        #expect(storedEntry.calories == 247)
        #expect(storedEntry.protein == 25)
        #expect(storedEntry.carbs == 14.5)
        #expect(storedEntry.fat == 7.5)
    }

    @Test("Built-in menu items cannot be edited or deleted")
    func rejectsBuiltInChanges() throws {
        let fixture = try makeFixture(custom: false)
        let defaultItem = MenuItem(name: "Built-in", baseCalories: 10, baseProtein: 0, baseCarbs: 0, baseFat: 0, category: .side)
        #expect(!defaultItem.isCustom)

        #expect(throws: CustomMenuItemEditor.EditError.self) {
            try CustomMenuItemEditor.save(
                item: fixture.item, restaurant: fixture.restaurant,
                name: "Changed", category: .drink, totals: MacroTotals(), in: fixture.context
            )
        }
        #expect(throws: CustomMenuItemEditor.EditError.self) {
            try CustomMenuItemEditor.delete(item: fixture.item, in: fixture.context)
        }
        #expect(fixture.item.name == "My Side")
        #expect(fixture.item.category == .side)
        #expect(fixture.item.baseCalories == 123.5)
        #expect(fixture.food.menuItem?.id == fixture.item.id)
        #expect(try fixture.context.fetchCount(FetchDescriptor<MenuItem>()) == 1)
    }

    @Test("Invalid nutrition or an empty name cannot create menu items")
    func rejectsInvalidInput() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let restaurant = Restaurant(name: "Test Restaurant")
        context.insert(restaurant)
        let invalidTotals = [
            MacroTotals(calories: -1), MacroTotals(protein: .nan),
            MacroTotals(carbs: .infinity), MacroTotals(fat: -0.5)
        ]
        for totals in invalidTotals {
            #expect(throws: CustomMenuItemEditor.EditError.self) {
                try CustomMenuItemEditor.save(
                    restaurant: restaurant, name: "Invalid", category: .side, totals: totals, in: context
                )
            }
        }
        #expect(throws: CustomMenuItemEditor.EditError.self) {
            try CustomMenuItemEditor.save(
                restaurant: restaurant, name: " \n\t ", category: .side, totals: originalTotals, in: context
            )
        }
        #expect(restaurant.menuItems.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<MenuItem>()) == 0)
    }

    @Test("Editing cannot move a custom item to another restaurant")
    func rejectsMovingRestaurants() throws {
        let fixture = try makeFixture()
        let other = Restaurant(name: "Another Restaurant")
        fixture.context.insert(other)
        #expect(throws: CustomMenuItemEditor.EditError.self) {
            try CustomMenuItemEditor.save(
                item: fixture.item, restaurant: other, name: "Changed",
                category: .drink, totals: originalTotals, in: fixture.context
            )
        }
        #expect(fixture.item.restaurant?.id == fixture.restaurant.id)
        #expect(fixture.item.name == "My Side")
        #expect(other.menuItems.isEmpty)
    }

    private enum SaveFailure: Error {
        case diskFull
    }

    @Test("A failed creation removes only its new row and preserves unrelated pending changes")
    func failedCreateCleansUp() throws {
        let fixture = try makeFixture()
        fixture.food.name = "Unrelated pending edit"
        #expect(throws: SaveFailure.self) {
            try CustomMenuItemEditor.save(
                restaurant: fixture.restaurant, name: "Not saved", category: .drink,
                totals: originalTotals, in: fixture.context,
                persist: { _ in throw SaveFailure.diskFull }
            )
        }
        #expect(fixture.restaurant.menuItems.count == 1)
        #expect(fixture.food.name == "Unrelated pending edit")
        try fixture.context.save()
        let readContext = ModelContext(fixture.container)
        #expect(try readContext.fetchCount(FetchDescriptor<MenuItem>()) == 1)
        let food = try #require(readContext.fetch(FetchDescriptor<FoodItem>()).first)
        #expect(food.name == "Unrelated pending edit")
    }

    @Test("A failed edit restores the original menu values without rolling back other work")
    func failedEditRestoresValues() throws {
        let fixture = try makeFixture()
        fixture.food.name = "Unrelated pending edit"
        #expect(throws: SaveFailure.self) {
            try CustomMenuItemEditor.save(
                item: fixture.item, restaurant: fixture.restaurant,
                name: "Not saved", category: .drink, totals: MacroTotals(), in: fixture.context,
                persist: { _ in throw SaveFailure.diskFull }
            )
        }
        #expect(fixture.item.name == "My Side")
        #expect(fixture.item.category == .side)
        #expect(fixture.item.baseCalories == 123.5)
        #expect(fixture.item.baseProtein == 12.5)
        #expect(fixture.item.baseCarbs == 7.25)
        #expect(fixture.item.baseFat == 3.75)
        #expect(fixture.food.name == "Unrelated pending edit")
        try fixture.context.save()
        let readContext = ModelContext(fixture.container)
        let item = try #require(readContext.fetch(FetchDescriptor<MenuItem>()).first)
        #expect(item.name == "My Side")
        let food = try #require(readContext.fetch(FetchDescriptor<FoodItem>()).first)
        #expect(food.name == "Unrelated pending edit")
    }

    @Test("A failed deletion restores the custom item and links without rolling back other work")
    func failedDeleteRestoresRelationships() throws {
        let fixture = try makeFixture()
        let modifier = MenuItemModifier(name: "Extra", calorieDelta: 10)
        fixture.item.modifiers = [modifier]
        try fixture.context.save()
        fixture.food.name = "Unrelated pending edit"
        let itemID = fixture.item.id

        #expect(throws: SaveFailure.self) {
            try CustomMenuItemEditor.delete(
                item: fixture.item, in: fixture.context,
                persist: { _ in throw SaveFailure.diskFull }
            )
        }
        #expect(fixture.restaurant.menuItems.count == 1)
        #expect(fixture.item.restaurant?.id == fixture.restaurant.id)
        #expect(fixture.item.modifiers.count == 1)
        #expect(modifier.menuItem?.id == itemID)
        #expect(fixture.food.menuItem?.id == itemID)
        #expect(fixture.food.name == "Unrelated pending edit")
        #expect(fixture.entry.calories == 247)

        // Persist after the failure to catch any lingering pending deletion.
        try fixture.context.save()
        let readContext = ModelContext(fixture.container)
        #expect(try readContext.fetchCount(FetchDescriptor<MenuItem>()) == 1)
        #expect(try readContext.fetchCount(FetchDescriptor<MenuItemModifier>()) == 1)
        let item = try #require(readContext.fetch(FetchDescriptor<MenuItem>()).first)
        #expect(item.id == itemID)
        #expect(item.restaurant?.id == fixture.restaurant.id)
        #expect(item.restaurant?.menuItems.contains(where: { $0.id == itemID }) == true)
        #expect(item.modifiers.first?.menuItem?.id == itemID)
        let food = try #require(readContext.fetch(FetchDescriptor<FoodItem>()).first)
        #expect(food.menuItem?.id == itemID)
        #expect(food.name == "Unrelated pending edit")

        // The user can retry the same delete successfully after the save recovers.
        try CustomMenuItemEditor.delete(item: item, in: readContext)
        let finalContext = ModelContext(fixture.container)
        #expect(try finalContext.fetchCount(FetchDescriptor<MenuItem>()) == 0)
        #expect(try finalContext.fetchCount(FetchDescriptor<MenuItemModifier>()) == 0)
        let retainedFood = try #require(finalContext.fetch(FetchDescriptor<FoodItem>()).first)
        #expect(retainedFood.menuItem == nil)
        #expect(retainedFood.name == "Unrelated pending edit")
    }
}
