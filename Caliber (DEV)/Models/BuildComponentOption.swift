//
//  BuildComponentOption.swift
//  Caliber (DEV)
//

import Foundation
import SwiftData

/// One selectable choice within a BuildComponentCategory (e.g. "Chicken").
/// Unlike MenuItemModifier, these are absolute nutrition values, not deltas —
/// for a build-your-own item, the sum of every selected option IS the item.
@Model
final class BuildComponentOption {
    var id: UUID
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var category: BuildComponentCategory?
    // Only options explicitly supported by the menu offer a double portion.
    // The stored default also keeps existing catalogs safe during migration.
    var supportsDouble: Bool = false

    init(name: String, calories: Double, protein: Double, carbs: Double, fat: Double, supportsDouble: Bool = false) {
        self.id = UUID()
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.supportsDouble = supportsDouble
    }
}
