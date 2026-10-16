import Combine
import Foundation

/// Favorites persist only opaque food keys, never nutrition, notes, photos or
/// diary history. Existing local preferences remain separate and unchanged.
@MainActor
final class FoodLibraryPreferences: ObservableObject {
  @Published private(set) var favoriteKeys: Set<String>
  static let maximumFavoriteCount = 500
  private static let storageKey = "food.library.favorites.v1"
  private let defaults: UserDefaults

  init(defaults: UserDefaults) {
    self.defaults = defaults
    let stored = defaults.array(forKey: Self.storageKey) ?? []
    // The app writes at most 500 IDs. Oversized or corrupted input is not a
    // reason to load an unbounded list into the UI or keep invalid values.
    let keys = stored.count <= 10_000 ? stored.compactMap { $0 as? String } : []
    favoriteKeys = Set(
      Set(keys.compactMap(Self.canonicalKey)).sorted().prefix(Self.maximumFavoriteCount))
    persist()
  }

  func isFavorite(_ key: String) -> Bool {
    guard let canonical = Self.canonicalKey(key) else { return false }
    return favoriteKeys.contains(canonical)
  }

  @discardableResult
  func setFavorite(_ enabled: Bool, for key: String) -> Bool {
    guard let canonical = Self.canonicalKey(key) else { return false }
    if enabled {
      guard favoriteKeys.count < Self.maximumFavoriteCount || favoriteKeys.contains(canonical)
      else { return false }
      favoriteKeys.insert(canonical)
    } else {
      favoriteKeys.remove(canonical)
    }
    persist()
    return true
  }

  private func persist() {
    defaults.set(favoriteKeys.sorted(), forKey: Self.storageKey)
  }

  private static func canonicalKey(_ key: String) -> String? {
    if FoodCatalogSourceType.contains(key: key) { return key }
    if key.hasPrefix("personal:") {
      let suffix = key.dropFirst("personal:".count)
      guard suffix.utf8.count == 64,
        suffix.utf8.allSatisfy({
          (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
        })
      else { return nil }
      return "personal:" + suffix.lowercased()
    }
    return nil
  }
}
