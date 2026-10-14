import Foundation
import SwiftData

@MainActor
enum FoodFavoriteEditor {
  enum EditError: LocalizedError {
    case invalidFood, limitReached
    var errorDescription: String? {
      switch self {
      case .invalidFood: "This food needs a name and valid nutrition before it can be saved."
      case .limitReached: "Your favorites are full. Remove one before adding another."
      }
    }
  }

  /// A personal favorite remains reusable even if its original diary log is removed.
  /// Removing a star never deletes the saved food or any diary entry.
  static func setFavorite(
    _ enabled: Bool, food: FoodItem, preferences: FoodLibraryPreferences,
    in context: ModelContext, persist: (ModelContext) throws -> Void = { try $0.save() }
  ) throws {
    let key = FoodReuseIndex.key(for: food)
    if enabled {
      let totals = MacroTotals(
        calories: food.calories, protein: food.proteinGrams, carbs: food.carbGrams,
        fat: food.fatGrams)
      guard !food.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !food.servingDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        totals.isValid
      else { throw EditError.invalidFood }
      guard
        preferences.isFavorite(key)
          || preferences.favoriteKeys.count < FoodLibraryPreferences.maximumFavoriteCount
      else { throw EditError.limitReached }
      let wasSaved = food.isSavedToLibrary
      if !wasSaved {
        food.isSavedToLibrary = true
        do { try persist(context) } catch {
          food.isSavedToLibrary = wasSaved
          throw error
        }
      }
    }
    guard preferences.setFavorite(enabled, for: key) else { throw EditError.limitReached }
  }
}
