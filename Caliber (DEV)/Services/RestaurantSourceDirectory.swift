import Foundation
import SwiftData

/// Links identify primary sources; they do not grant menu redistribution rights.
enum RestaurantSourceDirectory {
  static func nutritionURL(for name: String) -> URL? {
    switch FoodSearchText.normalized(name) {
    case "chipotle": URL(string: "https://www.chipotle.com/nutrition-calculator")
    case "chick fil a", "chickfila": URL(string: "https://www.chick-fil-a.com/nutrition-allergens")
    case "longhorn steakhouse", "longhorn":
      URL(string: "https://www.longhornsteakhouse.com/nutrition")
    default: nil
    }
  }
}

enum FoodSearchText {
  static func normalized(_ text: String) -> String {
    text.folding(
      options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
      locale: Locale(identifier: "en_US_POSIX")
    )
    .components(separatedBy: CharacterSet.alphanumerics.inverted)
    .filter { !$0.isEmpty }.joined(separator: " ")
  }
  static func matches(_ text: String, query: String) -> Bool {
    let text = normalized(text)
    return normalized(query).split(separator: " ").allSatisfy { text.contains($0) }
  }
}

enum RestaurantInputError: LocalizedError, Equatable {
  case invalidName, duplicateName
  var errorDescription: String? {
    switch self {
    case .invalidName: "Enter a restaurant name with 1–100 characters."
    case .duplicateName: "That restaurant is already in your list."
    }
  }
}

@MainActor
enum CustomRestaurantEditor {
  static func create(name: String, in context: ModelContext) throws -> Restaurant {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard (1...100).contains(trimmed.count), !FoodSearchText.normalized(trimmed).isEmpty else {
      throw RestaurantInputError.invalidName
    }
    let key = FoodSearchText.normalized(trimmed)
    guard
      try !context.fetch(FetchDescriptor<Restaurant>()).contains(where: {
        FoodSearchText.normalized($0.name) == key
      })
    else { throw RestaurantInputError.duplicateName }
    let restaurant = Restaurant(name: trimmed)
    context.insert(restaurant)
    do {
      try context.save()
      return restaurant
    } catch {
      context.delete(restaurant)
      throw error
    }
  }
}
