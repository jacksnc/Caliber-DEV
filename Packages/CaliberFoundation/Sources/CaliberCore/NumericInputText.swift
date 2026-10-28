import Foundation

/// Editable numbers must not contain thousands separators or scientific notation:
/// the strict input parser deliberately rejects both. Expand Double's round-trip
/// representation without rounding its significant digits.
public enum NumericInputText {
  public static func string(_ value: Double, locale: Locale = .current) -> String {
    guard value.isFinite else { return "" }
    let raw = String(value).lowercased()
    let parts = raw.split(separator: "e")
    var decimal = String(parts[0])
    if parts.count == 2, let exponent = Int(parts[1]) {
      let negative = decimal.hasPrefix("-")
      if negative { decimal.removeFirst() }
      let wholeDigits = decimal.split(separator: ".", omittingEmptySubsequences: false)[0].count
      let digits = decimal.replacingOccurrences(of: ".", with: "")
      let position = wholeDigits + exponent
      if position <= 0 {
        decimal = "0." + String(repeating: "0", count: -position) + digits
      } else if position >= digits.count {
        decimal = digits + String(repeating: "0", count: position - digits.count)
      } else {
        let index = digits.index(digits.startIndex, offsetBy: position)
        decimal = String(digits[..<index]) + "." + String(digits[index...])
      }
      if negative { decimal = "-" + decimal }
    }
    return decimal.replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
  }
}
