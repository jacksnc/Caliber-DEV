//
//  WeightEntry.swift
//  Caliber (DEV)
//

import Foundation
import SwiftData

/// A single weigh-in, used to chart progress over time.
@Model
final class WeightEntry {
    var id: UUID
    var date: Date
    var weightInPounds: Double
    /// Nil for existing standalone weigh-ins; only linked progress entries own this row.
    var progressEntry: ProgressEntry? = nil

    init(date: Date, weightInPounds: Double) {
        self.id = UUID()
        self.date = date
        self.weightInPounds = weightInPounds
    }
}
