//
//  MenuItemModifier.swift
//  Caliber (DEV)
//

import Foundation
import SwiftData

/// A customization for a restaurant MenuItem (e.g. "no cheese", "add bacon"),
/// stored as a nutrition delta so we don't need a separate MenuItem for every
/// possible combination of customizations.
@Model
final class MenuItemModifier {
    var id: UUID
    var name: String
    var calorieDelta: Double
    var proteinDelta: Double
    var carbDelta: Double
    var fatDelta: Double
    var menuItem: MenuItem?

    init(
        name: String,
        calorieDelta: Double = 0,
        proteinDelta: Double = 0,
        carbDelta: Double = 0,
        fatDelta: Double = 0
    ) {
        self.id = UUID()
        self.name = name
        self.calorieDelta = calorieDelta
        self.proteinDelta = proteinDelta
        self.carbDelta = carbDelta
        self.fatDelta = fatDelta
    }
}
