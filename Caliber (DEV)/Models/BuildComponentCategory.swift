//
//  BuildComponentCategory.swift
//  Caliber (DEV)
//

import Foundation
import SwiftData

/// One step of a build-your-own flow (e.g. "Protein", "Rice", "Salsa"),
/// with the options available at that step, whether it's required, and
/// whether one or several options can be picked.
@Model
final class BuildComponentCategory {
    var id: UUID
    var name: String
    var selectionType: SelectionType = SelectionType.single
    var isRequired: Bool
    var sortOrder: Int
    var template: BuildableItemTemplate?

    @Relationship(deleteRule: .cascade, inverse: \BuildComponentOption.category)
    var options: [BuildComponentOption] = []

    init(name: String, selectionType: SelectionType, isRequired: Bool, sortOrder: Int) {
        self.id = UUID()
        self.name = name
        self.selectionType = selectionType
        self.isRequired = isRequired
        self.sortOrder = sortOrder
    }
}
