import Foundation

/// GTIN validation shared by the camera and manual entry. Codes stay as text
/// so leading zeroes never disappear through a numeric conversion.
nonisolated enum BarcodeValue {
  enum ValidationError: LocalizedError, Equatable {
    case empty
    case invalidCharacters
    case unsupportedLength
    case invalidChecksum

    var errorDescription: String? {
      switch self {
      case .empty:
        "Enter the numbers printed below the barcode."
      case .invalidCharacters:
        "Use only the digits 0–9, including any leading zeroes."
      case .unsupportedLength:
        "Enter an 8, 12, 13, or 14 digit GTIN. UPC-E codes aren't supported."
      case .invalidChecksum:
        "That barcode doesn't pass its check digit. Check every digit and try again."
      }
    }
  }

  /// AVFoundation returns UPC-A as EAN-13 with a leading zero. Normalize
  /// that equivalent form to UPC-A, while preserving nonzero GTIN-14
  /// packaging indicators and all other leading zeroes.
  static func normalize(_ rawValue: String) throws -> String {
    let digits = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !digits.isEmpty else { throw ValidationError.empty }
    guard digits.utf8.allSatisfy({ (48...57).contains($0) }) else {
      throw ValidationError.invalidCharacters
    }
    guard [8, 12, 13, 14].contains(digits.utf8.count) else {
      throw ValidationError.unsupportedLength
    }

    let values = digits.utf8.map { Int($0 - 48) }
    // Starting at the rightmost payload digit, weights alternate 3, 1.
    // The check digit makes the resulting sum a multiple of ten.
    let weightedSum = values.dropLast().reversed().enumerated().reduce(0) { sum, element in
      sum + element.element * (element.offset.isMultiple(of: 2) ? 3 : 1)
    }
    guard (10 - weightedSum % 10) % 10 == values.last else {
      throw ValidationError.invalidChecksum
    }

    var normalized = digits
    if normalized.count == 14 && normalized.hasPrefix("0") {
      normalized.removeFirst()
    }
    if normalized.count == 13 && normalized.hasPrefix("0") {
      normalized.removeFirst()
    }
    return normalized
  }

  static func isValid(_ rawValue: String) -> Bool {
    (try? normalize(rawValue)) != nil
  }

  /// The 14-digit representation is useful as an equality/cache key across
  /// UPC-A, EAN-13, and zero-padded GTIN formats. It is never an integer.
  static func gtin14(_ rawValue: String) throws -> String {
    let normalized = try normalize(rawValue)
    return String(repeating: "0", count: 14 - normalized.count) + normalized
  }
}
