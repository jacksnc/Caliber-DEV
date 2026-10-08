//
//  FoodItem.swift
//  Caliber (DEV)
//

import Foundation
import SwiftData

/// A food that can be logged in the diary. This covers both generic,
/// manually-entered foods and foods copied from a restaurant's MenuItem
/// (in which case `menuItem` points back to where the nutrition came from).
@Model
final class FoodItem {
    var id: UUID
    var name: String
    var calories: Double
    var proteinGrams: Double
    var carbGrams: Double
    var fatGrams: Double
    var servingDescription: String
    var sourceType: FoodSourceType = FoodSourceType.generic
    /// Whether this appears in the Food Library's "My Foods" folder for
    /// reuse, as opposed to being a one-off tied to a single diary entry.
    var isSavedToLibrary: Bool = false
    var menuItem: MenuItem?

    init(
        name: String,
        calories: Double,
        proteinGrams: Double,
        carbGrams: Double,
        fatGrams: Double,
        servingDescription: String,
        sourceType: FoodSourceType = .generic,
        isSavedToLibrary: Bool = false,
        menuItem: MenuItem? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbGrams = carbGrams
        self.fatGrams = fatGrams
        self.servingDescription = servingDescription
        self.sourceType = sourceType
        self.isSavedToLibrary = isSavedToLibrary
        self.menuItem = menuItem
    }
}
