import Foundation
import Testing

@testable import Caliber__DEV_

@MainActor
@Suite("Local food favorite preferences")
struct FoodLibraryPreferencesTests {
  private let storageKey = "food.library.favorites.v1"
  private let personal = "personal:" + String(repeating: "ab", count: 32)

  @Test("Favorites reopen from sorted opaque keys and preserve unrelated settings")
  func persistenceAndPrivacy() throws {
    let fixture = try FavoriteDefaults()
    defer { fixture.clean() }
    fixture.defaults.set("existing setting", forKey: "unrelated.preference")
    let preferences = FoodLibraryPreferences(defaults: fixture.defaults)
    #expect(preferences.setFavorite(true, for: "usda-foundation:2346396"))
    #expect(preferences.setFavorite(true, for: personal))
    #expect(preferences.isFavorite(personal))
    let reopened = FoodLibraryPreferences(defaults: fixture.defaults)
    #expect(reopened.favoriteKeys == [personal, "usda-foundation:2346396"])
    let domain = try #require(fixture.defaults.persistentDomain(forName: fixture.name))
    #expect(Set(domain.keys) == [storageKey, "unrelated.preference"])
    #expect(domain["unrelated.preference"] as? String == "existing setting")
    #expect(domain[storageKey] as? [String] == [personal, "usda-foundation:2346396"])
    #expect(reopened.setFavorite(false, for: personal))
    #expect(!FoodLibraryPreferences(defaults: fixture.defaults).isFavorite(personal))
  }

  @Test("Only positive canonical USDA IDs and 64 hex personal hashes can be stored")
  func keyValidation() throws {
    let fixture = try FavoriteDefaults()
    defer { fixture.clean() }
    let preferences = FoodLibraryPreferences(defaults: fixture.defaults)
    for invalid in [
      "", "Rice, cooked", "barcode:012345678905", "usda-foundation:0", "usda-foundation:-1",
      "usda-foundation:001", "usda-foundation:1x", "usda-foundation:１２",
      "usda-foundation:999999999999999999999999999999",
      "personal:" + String(repeating: "a", count: 63),
      "personal:" + String(repeating: "g", count: 64),
    ] {
      #expect(!preferences.setFavorite(true, for: invalid))
      #expect(!preferences.isFavorite(invalid))
    }
    #expect(preferences.favoriteKeys.isEmpty)
    #expect(preferences.setFavorite(true, for: "usda-foundation:1"))
    #expect(preferences.setFavorite(true, for: "personal:" + String(repeating: "AB", count: 32)))
    #expect(preferences.isFavorite(personal))
    #expect(preferences.favoriteKeys == ["usda-foundation:1", personal])
  }

  @Test("Mixed corrupted values are sanitized while valid unique keys survive")
  func corruptedArrays() throws {
    let fixture = try FavoriteDefaults()
    defer { fixture.clean() }
    fixture.defaults.set(
      ["usda-foundation:1", 9, "bad key", ["name": "never store a food"], personal, personal],
      forKey: storageKey)
    let preferences = FoodLibraryPreferences(defaults: fixture.defaults)
    #expect(preferences.favoriteKeys == ["usda-foundation:1", personal])
    #expect(fixture.defaults.stringArray(forKey: storageKey) == [personal, "usda-foundation:1"])
    fixture.defaults.set("not an array", forKey: storageKey)
    #expect(FoodLibraryPreferences(defaults: fixture.defaults).favoriteKeys.isEmpty)
    #expect(fixture.defaults.stringArray(forKey: storageKey) == [])
  }

  @Test("The bound refuses new favorites until a slot is freed without deleting existing choices")
  func maximumFavorites() throws {
    let fixture = try FavoriteDefaults()
    defer { fixture.clean() }
    let preferences = FoodLibraryPreferences(defaults: fixture.defaults)
    #expect(FoodLibraryPreferences.maximumFavoriteCount == 500)
    for id in 1...500 { #expect(preferences.setFavorite(true, for: "usda-foundation:\(id)")) }
    #expect(!preferences.setFavorite(true, for: "usda-foundation:501"))
    #expect(preferences.favoriteKeys.count == 500)
    #expect(preferences.setFavorite(true, for: "usda-foundation:1"))
    #expect(preferences.setFavorite(false, for: "usda-foundation:1"))
    #expect(preferences.setFavorite(true, for: "usda-foundation:501"))
    #expect(
      !preferences.isFavorite("usda-foundation:1") && preferences.isFavorite("usda-foundation:501"))
    #expect(
      FoodLibraryPreferences(defaults: fixture.defaults).favoriteKeys == preferences.favoriteKeys)
  }

  @Test("Oversized stored lists are bounded deterministically after deduplicating")
  func boundedLoading() throws {
    let fixture = try FavoriteDefaults()
    defer { fixture.clean() }
    let duplicates = Array(repeating: "usda-foundation:1", count: 500)
    fixture.defaults.set(duplicates + [personal], forKey: storageKey)
    #expect(
      FoodLibraryPreferences(defaults: fixture.defaults).favoriteKeys == [
        "usda-foundation:1", personal,
      ])
    let many = (1...800).map { "usda-foundation:\($0)" }
    fixture.defaults.set(many, forKey: storageKey)
    let forward = FoodLibraryPreferences(defaults: fixture.defaults).favoriteKeys
    fixture.defaults.set(Array(many.reversed()), forKey: storageKey)
    let backward = FoodLibraryPreferences(defaults: fixture.defaults).favoriteKeys
    #expect(forward.count == 500 && forward == backward)
    fixture.defaults.set(Array(repeating: personal, count: 10_001), forKey: storageKey)
    #expect(FoodLibraryPreferences(defaults: fixture.defaults).favoriteKeys.isEmpty)
  }
}

@MainActor
private struct FavoriteDefaults {
  let name: String
  let defaults: UserDefaults
  init() throws {
    name = "Caliber.Food.Favorites.Tests." + UUID().uuidString
    defaults = try #require(UserDefaults(suiteName: name))
    defaults.removePersistentDomain(forName: name)
  }
  func clean() { defaults.removePersistentDomain(forName: name) }
}
