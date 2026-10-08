//
//  MenuItem.swift
//  Caliber (DEV)
//

import Foundation
import SwiftData

/// One item on a restaurant's flat menu, with catalog or user-entered nutrition, a
/// category for grouping (Entrées, Sides, etc.), and any available
/// customizations (modifiers).
@Model
final class MenuItem {
    var id: UUID
    var name: String
    var baseCalories: Double
    var baseProtein: Double
    var baseCarbs: Double
    var baseFat: Double
    var category: MenuCategory = MenuCategory.entree
    /// Existing catalog entries remain fixed; only user-created items are editable.
    var isCustom: Bool = false
    var restaurant: Restaurant?

    @Relationship(deleteRule: .cascade, inverse: \MenuItemModifier.menuItem)
    var modifiers: [MenuItemModifier] = []

    init(
        name: String,
        baseCalories: Double,
        baseProtein: Double,
        baseCarbs: Double,
        baseFat: Double,
        category: MenuCategory,
        isCustom: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.baseCalories = baseCalories
        self.baseProtein = baseProtein
        self.baseCarbs = baseCarbs
        self.baseFat = baseFat
        self.category = category
        self.isCustom = isCustom
    }
}
