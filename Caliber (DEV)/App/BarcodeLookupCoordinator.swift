import Combine
import Foundation

struct FoodLookupConfiguration: Decodable {
  let provider: String
  let contactEmail: String?
  let environment: String

  static func load() -> Self? {
    guard let url = Bundle.main.url(forResource: "FoodLookupConfiguration", withExtension: "json"),
      let data = try? Data(contentsOf: url)
    else { return nil }
    return try? JSONDecoder().decode(Self.self, from: data)
  }
  @MainActor func configuredService() -> (any BarcodeService)? {
    guard provider == "open-food-facts", let contactEmail,
      ["staging", "production"].contains(environment)
    else { return nil }
    return try? OpenFoodFactsBarcodeService(
      contactEmail: contactEmail, environment: environment == "production" ? .production : .staging)
  }
}

/// Account permission never implies permission to send a food barcode to another provider.
@MainActor
final class BarcodeLookupCoordinator: ObservableObject {
  @Published private(set) var hasPermission: Bool
  @Published private(set) var isBusy = false
  @Published private(set) var product: BarcodeNutritionProduct?
  @Published private(set) var message: String?
  let isConfigured: Bool
  private let service: any BarcodeService
  private let preferences: UserDefaults
  private var generation = UUID()
  private static let permissionKey = "food.barcode.open-food-facts.permission.version"
  private static let permissionDateKey = "food.barcode.open-food-facts.permission.date"
  private static let version = "barcode-open-food-facts-v1"

  init(service: any BarcodeService, isConfigured: Bool, preferences: UserDefaults) {
    self.service = service
    self.isConfigured = isConfigured
    self.preferences = preferences
    hasPermission = preferences.string(forKey: Self.permissionKey) == Self.version
  }
  static func configured(runtime: FoundationRuntime) -> BarcodeLookupCoordinator {
    #if DEBUG
      if runtime.testing && ProcessInfo.processInfo.arguments.contains("--barcode-fixture") {
        return BarcodeLookupCoordinator(
          service: FixtureBarcodeService(), isConfigured: true, preferences: runtime.preferenceStore
        )
      }
    #endif
    let service = FoodLookupConfiguration.load()?.configuredService()
    return BarcodeLookupCoordinator(
      service: service ?? DisabledBarcodeService(), isConfigured: service != nil,
      preferences: runtime.preferenceStore)
  }
  func setPermission(_ enabled: Bool) {
    cancel()
    hasPermission = enabled
    if enabled {
      preferences.set(Self.version, forKey: Self.permissionKey)
      preferences.set(Date(), forKey: Self.permissionDateKey)
    } else {
      preferences.removeObject(forKey: Self.permissionKey)
      preferences.removeObject(forKey: Self.permissionDateKey)
    }
  }
  func cancel() {
    generation = UUID()
    isBusy = false
    product = nil
    message = nil
  }
  func lookup(_ raw: String) async {
    guard !Task.isCancelled, !isBusy else { return }
    product = nil
    guard let code = try? BarcodeValue.normalize(raw) else {
      message = BarcodeLookupError.invalidBarcode.errorDescription
      return
    }
    guard isConfigured else {
      message = BarcodeLookupError.configurationRequired.errorDescription
      return
    }
    guard hasPermission else {
      message = "Allow online barcode lookup before sending this code."
      return
    }
    generation = UUID()
    let attempt = generation
    isBusy = true
    message = nil
    do {
      let result = try await service.lookupFood(barcode: code)
      try Task.checkCancellation()
      guard generation == attempt, hasPermission else { return }
      guard try BarcodeValue.gtin14(result.barcode) == BarcodeValue.gtin14(code) else {
        throw BarcodeLookupError.invalidResponse
      }
      product = result
    } catch is CancellationError {
      // Canceled screens cannot publish a late result.
    } catch {
      guard generation == attempt else { return }
      message =
        (error as? BarcodeLookupError)?.errorDescription
        ?? BarcodeLookupError.providerUnavailable.errorDescription
    }
    if generation == attempt { isBusy = false }
  }
}

extension FoodNutritionReference {
  static func barcode(_ product: BarcodeNutritionProduct) -> Self {
    Self(
      id: "barcode:" + product.barcode, name: product.name,
      totals: MacroTotals(
        calories: product.calories, protein: product.proteinGrams,
        carbs: product.carbGrams, fat: product.fatGrams),
      basisDescription: product.basisDescription, basisGrams: product.basisGrams,
      sourceLabel: product.sourceName + " GTIN " + product.barcode,
      sourceURL: product.sourceURL, attribution: product.attribution,
      sourceNote:
        "Community product data can be incomplete or outdated. Compare the nutrition and serving with your package before adding."
    )
  }
}

#if DEBUG
  /// Fictional product for isolated UI tests; never calls an external service.
  private struct FixtureBarcodeService: BarcodeService {
    func lookupFood(barcode: String) async throws -> BarcodeNutritionProduct {
      guard try BarcodeValue.gtin14(barcode) == BarcodeValue.gtin14("012345678905") else {
        throw BarcodeLookupError.notFound
      }
      return BarcodeNutritionProduct(
        barcode: "012345678905", name: "Fictional QA food", brand: nil,
        calories: 200, proteinGrams: 10, carbGrams: 25, fatGrams: 6,
        basisDescription: "1 serving (50 g)", basisGrams: 50,
        sourceURL: URL(string: "https://example.invalid/fixture")!, sourceName: "Fictional fixture",
        attribution: "Fictional test data")
    }
  }
#endif
