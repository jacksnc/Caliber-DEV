import Foundation
import CaliberCore

/// Shared parsing for editable nutrition. Invalid input stays invalid instead
/// of silently logging a different number than the user typed.
enum NutritionInput {
    static func number(_ text: String, locale: Locale = .current) -> Double? {
        try? QuantityParsing.nonnegative(text, locale: locale)
    }

    static func quantity(_ text: String, locale: Locale = .current) -> Double? {
        guard let value = number(text, locale: locale), value > 0 else { return nil }
        return value
    }

    static func format(_ value: Double, locale: Locale = .current) -> String {
        // String(Double) preserves fractional grams instead of rounding them
        // away when the user turns on macro editing.
        guard value.isFinite else { return "" }
        var text = String(value)
        // Editable decimal fields must round-trip even when Swift uses scientific notation.
        if let exponentIndex = text.firstIndex(of: "e"),
           let exponent = Int(text[text.index(after: exponentIndex)...]) {
            let mantissa = String(text[..<exponentIndex])
            let negative = mantissa.hasPrefix("-")
            let unsigned = negative ? String(mantissa.dropFirst()) : mantissa
            let digits = unsigned.replacingOccurrences(of: ".", with: "")
            let decimalPosition = (unsigned.firstIndex(of: ".").map { unsigned.distance(from: unsigned.startIndex, to: $0) } ?? unsigned.count) + exponent
            if decimalPosition <= 0 {
                text = "0." + String(repeating: "0", count: -decimalPosition) + digits
            } else if decimalPosition >= digits.count {
                text = digits + String(repeating: "0", count: decimalPosition - digits.count)
            } else {
                let split = digits.index(digits.startIndex, offsetBy: decimalPosition)
                text = String(digits[..<split]) + "." + String(digits[split...])
            }
            if negative { text = "-" + text }
        }
        if text.hasSuffix(".0") { text.removeLast(2) }
        return text.replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
    }

    static func totals(calories: String, protein: String, carbs: String, fat: String, locale: Locale = .current) -> MacroTotals? {
        guard let calories = number(calories, locale: locale), let protein = number(protein, locale: locale),
              let carbs = number(carbs, locale: locale), let fat = number(fat, locale: locale) else { return nil }
        return MacroTotals(calories: calories, protein: protein, carbs: carbs, fat: fat)
    }
    static func reformatted(_ text: String, from source: Locale, to destination: Locale) -> String {
        guard let value = number(text, locale: source) else { return text }
        return format(value, locale: destination)
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
