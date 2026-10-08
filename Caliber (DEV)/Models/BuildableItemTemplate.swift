//
//  BuildableItemTemplate.swift
//  Caliber (DEV)
//

import Foundation
import SwiftData

/// A "build your own" flow for a restaurant (e.g. Chipotle's entrée
/// builder): an ordered set of component categories the user picks from to
/// assemble one custom item, instead of choosing from a fixed menu.
@Model
final class BuildableItemTemplate {
    var id: UUID
    var name: String
    var restaurant: Restaurant?

    @Relationship(deleteRule: .cascade, inverse: \BuildComponentCategory.template)
    var categories: [BuildComponentCategory] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}
