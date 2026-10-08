//
//  Enums.swift
//  Caliber (DEV)
//
//  Shared enums used across the SwiftData models.
//

import Foundation

/// Where a FoodItem's nutrition info came from: typed in by hand, or copied
/// from a restaurant's official MenuItem.
enum FoodSourceType: String, Codable {
    case generic
    case restaurantMenuItem
}

/// Which section of the diary an entry belongs to.
enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

/// Activity level used by the TDEE (Total Daily Energy Expenditure) calculator.
enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary
    case lightlyActive
    case moderatelyActive
    case veryActive
    case extraActive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .lightlyActive: return "Lightly Active"
        case .moderatelyActive: return "Moderately Active"
        case .veryActive: return "Very Active"
        case .extraActive: return "Extra Active"
        }
    }

    /// Standard activity multiplier used to turn BMR into TDEE.
    var activityMultiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        case .extraActive: return 1.9
        }
    }
}

/// Groups a restaurant's flat (non-buildable) menu items for display,
/// e.g. so a menu screen can show "Entrées", "Sides", "Drinks" as sections.
enum MenuCategory: String, Codable, CaseIterable, Identifiable {
    case appetizer
    case entree
    case side
    case drink
    case dessert

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appetizer: return "Appetizers"
        case .entree: return "Entrées"
        case .side: return "Sides"
        case .drink: return "Drinks"
        case .dessert: return "Desserts"
        }
    }

    /// The order categories should appear in on a menu screen.
    static var displayOrder: [MenuCategory] {
        [.appetizer, .entree, .side, .drink, .dessert]
    }
}

/// How many options can be picked within one BuildComponentCategory of a
/// "build your own" item flow (e.g. Chipotle's entrée builder).
enum SelectionType: String, Codable {
    case single
    case multiple
}
