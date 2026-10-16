import CaliberDatabase
import Foundation
import SwiftData
import Testing

@testable import Caliber__DEV_

@MainActor @Test func productionRestaurantRegistryIsHonestlyEmpty() async throws {
  let catalog = try await BundledRestaurantMenuService.load()
  #expect(!catalog.fictional && catalog.restaurants.isEmpty && catalog.sources.isEmpty)
}

@MainActor @Test func importedRestaurantPortionLogsAnEditableCopyWithoutSourceRows() throws {
  let catalog = try RestaurantMenuCatalog(
    data: BundledRestaurantMenuService.fixtureData(), allowFictional: true)
  let restaurant = try #require(catalog.restaurants.first)
  let item = try #require(restaurant.items.first { $0.id == "fictional-chicken" })
  let source = try #require(catalog.sources.first)
  let reference = BundledRestaurantMenuService.reference(
    item: item, restaurant: restaurant, source: source)
  #expect(try reference.portionTotals(grams: 100).calories == 200)
  let container = try ModelContainer(
    for: FoodItem.self, DiaryEntry.self, Restaurant.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true))
  let context = ModelContext(container)
  let entry = try ReferenceFoodLogger.log(
    reference: reference, grams: 100,
    override: MacroTotals(calories: 230, protein: 25, carbs: 15, fat: 7),
    date: .now, meal: .breakfast, in: context)
  #expect(entry.calories == 230 && entry.mealType == .breakfast)
  #expect(entry.foodItem?.sourceType == .restaurantMenuItem)
  #expect(entry.foodItem?.menuItem == nil)
  #expect(entry.foodItem?.servingDescription.contains(item.id) == true)
  #expect(try context.fetch(FetchDescriptor<Restaurant>()).isEmpty)
  #expect(try context.fetch(FetchDescriptor<MenuItem>()).isEmpty)
  #expect(item.calories == 400 && reference.totals.calories == 400)
  entry.foodItem?.calories = 999
  #expect(item.calories == 400)
}

@MainActor @Test func importedUnweighedRestaurantServingNeverInventsGrams() throws {
  let catalog = try RestaurantMenuCatalog(
    data: BundledRestaurantMenuService.fixtureData(), allowFictional: true)
  let restaurant = try #require(catalog.restaurants.first)
  let item = try #require(restaurant.items.first { $0.id == "fictional-side" })
  let reference = BundledRestaurantMenuService.reference(
    item: item, restaurant: restaurant, source: try #require(catalog.sources.first))
  #expect(reference.basisGrams == nil)
  #expect(try reference.portionTotals(grams: nil).calories == 80)
  #expect(throws: (any Error).self) { try reference.portionTotals(grams: 100) }
}
