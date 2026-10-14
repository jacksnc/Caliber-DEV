import CryptoKit
import Foundation

/// A view of existing local foods, not another stored food or diary entry.
/// Quantity is the newest logged serving count, including fractional servings.
@MainActor
struct ReusableFood: Identifiable {
  let id: String
  let food: FoodItem
  let quantity: Double
  let lastLoggedAt: Date?
  let logCount: Int
}

/// Derives recents and frequent foods without changing the diary or library.
/// A fresh FoodItem is created for every log, so its UUID cannot identify the
/// same reusable food. Exact food values identify a preparation and portion.
@MainActor
enum FoodReuseIndex {
  static func key(for food: FoodItem) -> String {
    let fields = [
      "caliber-personal-food-v1", food.name, food.servingDescription,
      food.sourceType.rawValue,
      bits(food.calories), bits(food.proteinGrams), bits(food.carbGrams), bits(food.fatGrams),
      food.menuItem?.id.uuidString.lowercased() ?? "",
      food.menuItem?.restaurant?.id.uuidString.lowercased() ?? "",
    ]
    var hash = SHA256()
    for field in fields {
      let bytes = Data(field.utf8)
      // Length framing prevents ambiguous joins such as ["ab", "c"] and
      // ["a", "bc"]. Numeric bits avoid locale or display-rounding changes.
      var count = UInt64(bytes.count).bigEndian
      withUnsafeBytes(of: &count) { hash.update(data: Data($0)) }
      hash.update(data: bytes)
    }
    return "personal:" + hash.finalize().map { String(format: "%02x", $0) }.joined()
  }

  static func build(entries: [DiaryEntry], savedFoods: [FoodItem], through: Date) -> [ReusableFood]
  {
    guard through.timeIntervalSinceReferenceDate.isFinite else { return [] }
    let rows = entries.compactMap { entry -> Row? in
      guard entry.date.timeIntervalSinceReferenceDate.isFinite, entry.date <= through,
        let food = entry.foodItem, isValid(food: food, quantity: entry.quantity)
      else { return nil }
      return Row(entry: entry, food: food, key: key(for: food))
    }.sorted { lhs, rhs in
      if lhs.entry.date != rhs.entry.date { return lhs.entry.date > rhs.entry.date }
      if lhs.entry.id != rhs.entry.id { return lhs.entry.id.uuidString < rhs.entry.id.uuidString }
      if lhs.key != rhs.key { return lhs.key < rhs.key }
      return lhs.entry.quantity < rhs.entry.quantity
    }

    var groups: [String: ReusableFood] = [:]
    var seenRows = Set<UUID>()
    for row in rows where seenRows.insert(row.entry.id).inserted {
      if let prior = groups[row.key] {
        groups[row.key] = ReusableFood(
          id: prior.id, food: prior.food, quantity: prior.quantity,
          lastLoggedAt: prior.lastLoggedAt, logCount: prior.logCount + 1)
      } else {
        groups[row.key] = ReusableFood(
          id: row.key, food: row.food, quantity: row.entry.quantity,
          lastLoggedAt: row.entry.date, logCount: 1)
      }
    }

    // Prefer an actual My Foods representative. A deterministic UUID tie
    // makes the result independent of the fetch order of duplicate saved foods.
    let saved = savedFoods.filter { $0.isSavedToLibrary && isValid(food: $0, quantity: 1) }
      .sorted { $0.id.uuidString < $1.id.uuidString }
    var seenSavedKeys = Set<String>()
    for food in saved {
      let id = key(for: food)
      guard seenSavedKeys.insert(id).inserted else { continue }
      let prior = groups[id]
      groups[id] = ReusableFood(
        id: id, food: food, quantity: prior?.quantity ?? 1,
        lastLoggedAt: prior?.lastLoggedAt, logCount: prior?.logCount ?? 0)
    }
    return groups.values.sorted { $0.id < $1.id }
  }

  static func recent(_ foods: [ReusableFood], limit: Int = 10) -> [ReusableFood] {
    guard limit > 0 else { return [] }
    return Array(
      foods.filter(isValidHistory).sorted { lhs, rhs in
        if lhs.lastLoggedAt != rhs.lastLoggedAt {
          return (lhs.lastLoggedAt ?? .distantPast) > (rhs.lastLoggedAt ?? .distantPast)
        }
        return lhs.id < rhs.id
      }.prefix(limit))
  }

  static func frequent(_ foods: [ReusableFood], limit: Int = 10) -> [ReusableFood] {
    guard limit > 0 else { return [] }
    return Array(
      foods.filter(isValidHistory).sorted { lhs, rhs in
        if lhs.logCount != rhs.logCount { return lhs.logCount > rhs.logCount }
        if lhs.lastLoggedAt != rhs.lastLoggedAt {
          return (lhs.lastLoggedAt ?? .distantPast) > (rhs.lastLoggedAt ?? .distantPast)
        }
        return lhs.id < rhs.id
      }.prefix(limit))
  }

  private static func bits(_ value: Double) -> String {
    // +0 and -0 describe the same nutrition; all other bits stay exact.
    String((value == 0 ? Double.zero : value).bitPattern, radix: 16)
  }

  private static func isValid(food: FoodItem, quantity: Double) -> Bool {
    guard !food.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !food.servingDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      quantity.isFinite, quantity > 0
    else { return false }
    return [food.calories, food.proteinGrams, food.carbGrams, food.fatGrams]
      .allSatisfy { $0.isFinite && $0 >= 0 && ($0 * quantity).isFinite }
  }

  private static func isValidHistory(_ food: ReusableFood) -> Bool {
    food.logCount > 0 && food.lastLoggedAt?.timeIntervalSinceReferenceDate.isFinite == true
      && isValid(food: food.food, quantity: food.quantity)
  }

  private struct Row {
    let entry: DiaryEntry
    let food: FoodItem
    let key: String
  }
}
