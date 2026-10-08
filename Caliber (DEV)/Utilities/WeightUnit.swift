import Foundation

/// Storage always uses pounds. The selected display unit changes only presentation.
enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case pounds
    case kilograms

    var id: String { rawValue }
    var symbol: String { self == .pounds ? "lb" : "kg" }
    var displayName: String { self == .pounds ? "Pounds" : "Kilograms" }

    private static let kilogramsPerPound = 0.45359237

    func toPounds(_ value: Double) -> Double {
        self == .pounds ? value : value / Self.kilogramsPerPound
    }

    func fromPounds(_ value: Double) -> Double {
        self == .pounds ? value : value * Self.kilogramsPerPound
    }
}
