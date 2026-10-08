import Foundation
import SwiftData

/// Owns changes to user-created menu rows. Logged foods keep their snapshots.
@MainActor
enum CustomMenuItemEditor {
    enum EditError: LocalizedError {
        case invalidInput
        case fixedMenuItem
        case differentRestaurant

        var errorDescription: String? {
            switch self {
            case .invalidInput:
                "Enter an item name and valid, nonnegative nutrition values."
            case .fixedMenuItem:
                "Only menu items you created can be edited or deleted."
            case .differentRestaurant:
                "An existing menu item must stay in its original restaurant."
            }
        }
    }

    /// Creates a custom item, or updates the same custom item without duplicating it.
    @discardableResult
    static func save(
        item: MenuItem? = nil,
        restaurant: Restaurant,
        name: String,
        category: MenuCategory,
        totals: MacroTotals,
        in context: ModelContext,
        persist: (ModelContext) throws -> Void = { try $0.save() }
    ) throws -> MenuItem {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, totals.isValid else { throw EditError.invalidInput }

        if let item {
            guard item.isCustom else { throw EditError.fixedMenuItem }
            guard item.restaurant?.id == restaurant.id else { throw EditError.differentRestaurant }
            let originalName = item.name
            let originalCategory = item.category
            let originalTotals = MacroTotals(
                calories: item.baseCalories, protein: item.baseProtein,
                carbs: item.baseCarbs, fat: item.baseFat
            )

            update(item, name: trimmedName, category: category, totals: totals)
            do {
                try persist(context)
            } catch {
                // No global rollback: unrelated changes in this context stay intact.
                update(item, name: originalName, category: originalCategory, totals: originalTotals)
                throw error
            }
            return item
        }

        let newItem = MenuItem(
            name: trimmedName,
            baseCalories: totals.calories, baseProtein: totals.protein,
            baseCarbs: totals.carbs, baseFat: totals.fat,
            category: category, isCustom: true
        )
        context.insert(newItem)
        restaurant.menuItems.append(newItem)
        do {
            try persist(context)
        } catch {
            restaurant.menuItems.removeAll { $0.id == newItem.id }
            context.delete(newItem)
            throw error
        }
        return newItem
    }

    /// Deletes the catalog row, never the foods or diary entries logged from it.
    static func delete(
        item: MenuItem,
        in context: ModelContext,
        persist: (ModelContext) throws -> Void = { try $0.save() }
    ) throws {
        guard item.isCustom else { throw EditError.fixedMenuItem }
        let itemID = item.id
        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.menuItem?.id == itemID })
        let linkedFoods = try context.fetch(descriptor)
        let restaurant = item.restaurant
        let originalIndex = restaurant?.menuItems.firstIndex { $0.id == itemID }
        let modifiers = item.modifiers

        // These foods already contain their own nutrition and names. Remove just
        // the optional provenance link so a deleted menu row cannot affect them.
        linkedFoods.forEach { $0.menuItem = nil }
        context.delete(item)
        do {
            try persist(context)
        } catch {
            // Re-register the pending deletion, then restore only relationships
            // this operation changed. Do not discard other unsaved app work.
            context.insert(item)
            // Flush the canceled deletion before rebuilding its inverse links.
            // Clearing and relinking also makes the next save persist the repair.
            context.processPendingChanges()
            item.restaurant = nil
            for modifier in modifiers {
                context.insert(modifier)
            }
            item.modifiers = modifiers
            modifiers.forEach { $0.menuItem = item }
            if let restaurant, !restaurant.menuItems.contains(where: { $0.id == itemID }) {
                let index = min(originalIndex ?? restaurant.menuItems.count, restaurant.menuItems.count)
                restaurant.menuItems.insert(item, at: index)
            }
            // SwiftData can defer restoring the inverse after canceling a deletion.
            // Restore it explicitly so this item is immediately editable again.
            item.restaurant = restaurant
            linkedFoods.forEach { $0.menuItem = item }
            throw error
        }
    }

    private static func update(_ item: MenuItem, name: String, category: MenuCategory, totals: MacroTotals) {
        item.name = name
        item.category = category
        item.baseCalories = totals.calories
        item.baseProtein = totals.protein
        item.baseCarbs = totals.carbs
        item.baseFat = totals.fat
    }
}
