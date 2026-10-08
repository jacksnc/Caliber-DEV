import Foundation

/// Shared parsing for editable nutrition. Invalid input stays invalid instead
/// of silently logging a different number than the user typed.
enum NutritionInput {
    static func number(_ text: String, locale: Locale = .current) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = locale.decimalSeparator ?? "."
        let normalized = separator == "." ? trimmed : trimmed.replacingOccurrences(of: separator, with: ".")
        guard let value = Double(normalized), value.isFinite, value >= 0 else { return nil }
        return value
    }

    static func quantity(_ text: String) -> Double? {
        guard let value = number(text), value > 0 else { return nil }
        return value
    }

    static func format(_ value: Double, locale: Locale = .current) -> String {
        // String(Double) preserves fractional grams instead of rounding them
        // away when the user turns on macro editing.
        var text = String(value)
        if text.hasSuffix(".0") { text.removeLast(2) }
        return text.replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
    }

    static func totals(calories: String, protein: String, carbs: String, fat: String) -> MacroTotals? {
        guard let calories = number(calories), let protein = number(protein),
              let carbs = number(carbs), let fat = number(fat) else { return nil }
        return MacroTotals(calories: calories, protein: protein, carbs: carbs, fat: fat)
    }
}

extension MacroTotals {
    var isValid: Bool {
        [calories, protein, carbs, fat].allSatisfy { $0.isFinite && $0 >= 0 }
    }

    func scaled(by quantity: Double) -> MacroTotals {
        MacroTotals(calories: calories * quantity, protein: protein * quantity,
                    carbs: carbs * quantity, fat: fat * quantity)
    }
}
