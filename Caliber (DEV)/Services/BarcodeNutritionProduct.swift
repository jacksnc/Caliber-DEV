import Foundation

/// Read-only provider data. The person checks the package's label and serving
/// before the review screen creates their own editable food.
struct BarcodeNutritionProduct: Equatable, Sendable {
  let barcode: String
  let name: String
  let brand: String?
  let calories: Double
  let proteinGrams: Double
  let carbGrams: Double
  let fatGrams: Double
  let basisDescription: String
  /// Explicit mass for this basis; nil for volumes. Never equate ml and g.
  let basisGrams: Double?
  let sourceURL: URL
  let sourceName: String
  let attribution: String
}

enum BarcodeLookupError: LocalizedError, Equatable {
  case invalidBarcode
  case notFound
  case incompleteNutrition
  case rateLimited(retryAfterSeconds: Int)
  case offline
  case invalidResponse
  case providerUnavailable
  case configurationRequired

  var errorDescription: String? {
    switch self {
    case .invalidBarcode: "Enter a valid numeric food barcode."
    case .notFound: "This barcode was not found. You can enter its label manually."
    case .incompleteNutrition: "This product needs a label check. Enter its nutrition manually."
    case .rateLimited: "Barcode lookup is busy. Wait a moment, then try again."
    case .offline: "Barcode lookup needs an internet connection. You can enter its label manually."
    case .invalidResponse: "This product response could not be checked. Enter its label manually."
    case .providerUnavailable:
      "The barcode provider is unavailable. You can enter its label manually."
    case .configurationRequired:
      "Online barcode lookup is not configured. You can enter its label manually."
    }
  }
}
