import CaliberDatabase
import Foundation

/// A read-only collection of USDA label records. Looking up a barcode here
/// never contacts a provider or writes a food into the person's diary.
@MainActor
struct BundledBarcodeService: BarcodeService {
  private let database: PackagedFoodCatalog
  private static var pending: Task<Result<PackagedFoodCatalog, PackagedFoodCatalogError>, Never>?

  init(database: PackagedFoodCatalog) { self.database = database }

  static func prepared() async -> (service: BundledBarcodeService?, count: Int?) {
    if pending == nil {
      guard let url = Bundle.main.url(forResource: "PackagedFoodDatabase", withExtension: "sqlite"),
        let manifestURL = Bundle.main.url(
          forResource: "PackagedFoodDatabaseManifest", withExtension: "json"),
        let size = try? manifestURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
        (1...100_000).contains(size),
        let data = try? Data(contentsOf: manifestURL),
        let manifest = try? JSONDecoder().decode(PackagedManifest.self, from: data),
        manifest.schemaVersion == 1, (1...50_000).contains(manifest.productCount)
      else { return (nil, nil) }
      let hash = manifest.databaseSHA256
      let count = manifest.productCount
      pending = Task.detached(priority: .userInitiated) {
        do {
          let database = try PackagedFoodCatalog(url: url, expectedSHA256: hash)
          guard try database.foodCount == count else { return .failure(.invalidData) }
          return .success(database)
        } catch { return .failure(.invalidData) }
      }
    }
    guard let pending, case .success(let database) = await pending.value,
      let count = try? database.foodCount
    else { return (nil, nil) }
    return (BundledBarcodeService(database: database), count)
  }

  func lookupFood(barcode: String) async throws -> BarcodeNutritionProduct {
    try Task.checkCancellation()
    guard let key = try? BarcodeValue.gtin14(barcode) else {
      throw BarcodeLookupError.invalidBarcode
    }
    guard let product = try database.product(gtin14: key) else { throw BarcodeLookupError.notFound }
    try Task.checkCancellation()
    return try Self.product(product, requestedBarcode: barcode)
  }

  /// USDA standardizes branded nutrients to 100 g OR 100 mL according to the
  /// supplied label unit. Only a gram basis can produce a gram-weight review.
  static func product(_ source: PackagedCatalogProduct, requestedBarcode: String) throws
    -> BarcodeNutritionProduct
  {
    guard try BarcodeValue.gtin14(requestedBarcode) == source.gtin14,
      ["g", "mL"].contains(source.basisUnit),
      let quantity = source.servingQuantity, quantity.isFinite, quantity > 0, quantity <= 10_000,
      source.servingUnit == source.basisUnit
    else { throw BarcodeLookupError.invalidResponse }
    let totals = MacroTotals(
      calories: source.calories, protein: source.proteinGrams,
      carbs: source.carbGrams, fat: source.fatGrams
    ).scaled(by: quantity / 100)
    guard totals.isValid else { throw BarcodeLookupError.incompleteNutrition }
    let basis =
      "1 serving (\(NutritionInput.format(quantity, locale: Locale(identifier: "en_US"))) \(source.basisUnit))"
    let label = source.servingLabel.flatMap { $0.isEmpty ? nil : $0 }
    guard let url = URL(string: "https://fdc.nal.usda.gov/food-details/\(source.fdcID)/nutrients")
    else {
      throw BarcodeLookupError.invalidResponse
    }
    return BarcodeNutritionProduct(
      barcode: requestedBarcode, name: source.name,
      brand: source.brand.isEmpty ? nil : source.brand,
      calories: totals.calories, proteinGrams: totals.protein,
      carbGrams: totals.carbs, fatGrams: totals.fat,
      basisDescription: basis + (label.map { " · " + $0 } ?? ""),
      basisGrams: source.basisUnit == "g" ? quantity : nil,
      sourceURL: url, sourceName: "USDA Branded",
      attribution:
        "USDA FoodData Central · Branded Foods · April 2026 · Published \(source.publicationDate)",
      sourceNote:
        "USDA label reference from April 2026. Compare the product, preparation, serving and nutrition with your current package. Volume servings are not converted to grams.",
      sourceRecordID: String(source.fdcID))
  }
}

private struct PackagedManifest: Decodable {
  let schemaVersion: Int
  let databaseSHA256: String
  let productCount: Int
}
