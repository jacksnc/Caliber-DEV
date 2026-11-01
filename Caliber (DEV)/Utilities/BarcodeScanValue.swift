import FoodCore

/// Camera symbology removes the EAN-8/UPC-E ambiguity. Never guess or repair digits.
nonisolated enum BarcodeScanValue {
  static func normalize(_ value: String, symbology: BarcodeSymbology) -> String? {
    let result = BarcodeNormalizer.normalize(value, symbology: symbology)
    guard result.candidates.count == 1, let first = result.candidates.first else { return nil }
    return try? BarcodeValue.normalize(first.gtin.digits14)
  }
}
