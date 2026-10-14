import Foundation

/// A provider returns an immutable result; only an explicit Add creates a
/// personal diary copy. Cameras and health records never go to the provider.
@MainActor
protocol BarcodeService {
  func lookupFood(barcode: String) async throws -> BarcodeNutritionProduct
}

/// Default until the owner chooses a provider and configures its contact.
struct DisabledBarcodeService: BarcodeService {
  func lookupFood(barcode: String) async throws -> BarcodeNutritionProduct {
    throw BarcodeLookupError.configurationRequired
  }
}
