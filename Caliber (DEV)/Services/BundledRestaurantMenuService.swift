import CaliberCore
import CaliberDatabase
import Foundation

/// Public menu values never become SwiftData menu rows. Only reviewed personal
/// food snapshots and user-created menu items enter the private store.
enum BundledRestaurantMenuService {
  static func load(testing: Bool = false) async throws -> RestaurantMenuCatalog {
    #if DEBUG
      if testing && ProcessInfo.processInfo.arguments.contains("--restaurant-menu-fixture") {
        return try RestaurantMenuCatalog(data: fixtureData(), allowFictional: true)
      }
    #endif
    let catalog = try await prepared.value.get()
    guard catalog.restaurants.isEmpty || FeatureCatalog.isEnabled("feature.fuel-13") else {
      throw MenuAvailabilityError.pendingRelease
    }
    return catalog
  }

  private static let prepared = Task.detached(priority: .userInitiated) {
    () -> Result<RestaurantMenuCatalog, Error> in
    do {
      guard let url = Bundle.main.url(forResource: "RestaurantMenuCatalog", withExtension: "json"),
        let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
        (1...5_000_000).contains(bytes)
      else { throw CocoaError(.fileReadCorruptFile) }
      return .success(try RestaurantMenuCatalog(data: Data(contentsOf: url)))
    } catch { return .failure(error) }
  }

  static func reference(
    item: RestaurantMenuCatalogItem, restaurant: RestaurantMenuCatalogRestaurant,
    source: RestaurantMenuCatalogSource
  ) -> FoodNutritionReference {
    FoodNutritionReference(
      id: "restaurant-menu:" + restaurant.id + ":" + item.id,
      name: restaurant.name + " · " + item.name,
      totals: MacroTotals(
        calories: item.calories, protein: item.proteinGrams,
        carbs: item.carbGrams, fat: item.fatGrams),
      basisDescription: item.servingDescription, basisGrams: item.servingGrams,
      sourceLabel: source.id + " / " + item.id + " · " + source.retrievedOn,
      sourceURL: URL(string: source.url)!, attribution: source.license.attribution,
      sourceNote:
        "Menu source retrieved " + source.retrievedOn
        + ". Compare the item, preparation and serving with your order. You can adjust your copy before logging.",
      sourceType: .restaurantMenuItem)
  }

  #if DEBUG
    static func fixtureData() throws -> Data {
      try JSONSerialization.data(withJSONObject: [
        "schemaVersion": 1, "fictional": true, "inputSHA256": String(repeating: "a", count: 64),
        "sources": [
          [
            "id": "fictional-kitchen", "name": "Fictional Test Kitchen",
            "url": "https://example.invalid/menu",
            "retrievedOn": "2026-10-15",
            "license": [
              "status": "fixture", "permissionReference": "Synthetic test fixture only",
              "attribution": "Fictional test data",
            ],
          ]
        ],
        "restaurants": [
          [
            "id": "fictional-kitchen", "name": "Fictional Test Kitchen",
            "sourceID": "fictional-kitchen",
            "items": [
              [
                "id": "fictional-chicken", "name": "Test Chicken Plate", "category": "entree",
                "servingDescription": "1 plate (200 g)", "servingGrams": 200,
                "calories": 400, "proteinGrams": 40, "carbGrams": 30, "fatGrams": 13,
              ],
              [
                "id": "fictional-side", "name": "Test Vegetable Side", "category": "side",
                "servingDescription": "1 side", "servingGrams": NSNull(),
                "calories": 80, "proteinGrams": 3, "carbGrams": 12, "fatGrams": 2,
              ],
            ],
          ]
        ],
      ])
    }
  #endif
}

private enum MenuAvailabilityError: LocalizedError {
  case pendingRelease
  var errorDescription: String? {
    "Imported menu coverage is pending source approval and release readiness."
  }
}
