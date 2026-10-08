//
//  SavedMeal.swift
//  Caliber (DEV)
//

import Foundation
import SwiftData

/// A reusable named combination of foods (e.g. "My Usual Breakfast") that can
/// be logged all at once from the Food Library's "My Meals" folder.
@Model
final class SavedMeal {
    var id: UUID
    var name: String

    @Relationship(deleteRule: .cascade, inverse: \SavedMealItem.savedMeal)
    var items: [SavedMealItem] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}
