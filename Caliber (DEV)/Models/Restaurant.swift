//
//  Restaurant.swift
//  Caliber (DEV)
//

import Foundation
import SwiftData

/// A restaurant in the restaurant library (e.g. "Chick-fil-A"), with its flat
/// menu items (if any) and its "build your own" item flows (if any) — a
/// restaurant can have either, or both.
@Model
final class Restaurant {
    var id: UUID
    var name: String

    @Relationship(deleteRule: .cascade, inverse: \MenuItem.restaurant)
    var menuItems: [MenuItem] = []

    @Relationship(deleteRule: .cascade, inverse: \BuildableItemTemplate.restaurant)
    var buildableTemplates: [BuildableItemTemplate] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}
