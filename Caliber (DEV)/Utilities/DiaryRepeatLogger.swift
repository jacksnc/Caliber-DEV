import Foundation
import SwiftData

/// Repeats existing diary foods as independent, editable copies.
/// No saved food, restaurant item or earlier diary entry is edited by this operation.
@MainActor
enum DiaryRepeatLogger {
  enum ValidationError: LocalizedError, Equatable {
    case invalidInput

    var errorDescription: String? {
      "These entries cannot be copied. Check the food details and quantities, then try again."
    }
  }

  /// Uses the same checks and serving math as the actual copy, without changing any models.
  static func preview(entries: [DiaryEntry]) throws -> MacroTotals {
    try snapshots(entries).totals
  }

  @discardableResult
  static func copy(
    entries: [DiaryEntry], to date: Date, meal: MealType? = nil, in context: ModelContext,
    persist: (ModelContext) throws -> Void = { try $0.save() }
  ) throws -> [DiaryEntry] {
    guard date.timeIntervalSinceReferenceDate.isFinite else { throw ValidationError.invalidInput }
    // Read every source before inserting anything. Older logs may share one FoodItem.
    let frozen = try snapshots(entries).foods
    let menuLinks = try frozen.map { try resolveMenu($0.menuItem, in: context) }
    var foods: [FoodItem] = []
    var copies: [DiaryEntry] = []
    for (snapshot, menuItem) in zip(frozen, menuLinks) {
      let food = FoodItem(
        name: snapshot.name, calories: snapshot.macros.calories,
        proteinGrams: snapshot.macros.protein, carbGrams: snapshot.macros.carbs,
        fatGrams: snapshot.macros.fat, servingDescription: snapshot.servingDescription,
        sourceType: snapshot.sourceType, isSavedToLibrary: false, menuItem: menuItem)
      let entry = DiaryEntry(
        date: date, mealType: meal ?? snapshot.meal, foodItem: food,
        quantity: snapshot.quantity, note: snapshot.note)
      context.insert(food)
      context.insert(entry)
      foods.append(food)
      copies.append(entry)
    }
    do {
      try persist(context)
      return copies
    } catch {
      // A global rollback would discard unrelated drafts in the shared context.
      // Delete only the rows created by this attempted copy, and leave those drafts pending.
      for entry in copies { context.delete(entry) }
      for food in foods { context.delete(food) }
      throw error
    }
  }

  private struct Snapshot {
    let name: String
    let macros: MacroTotals
    let servingDescription: String
    let sourceType: FoodSourceType
    let menuItem: MenuItem?
    let quantity: Double
    let meal: MealType
    let note: String?
  }

  private static func snapshots(_ entries: [DiaryEntry]) throws -> (
    foods: [Snapshot], totals: MacroTotals
  ) {
    guard !entries.isEmpty, Set(entries.map(\.id)).count == entries.count else {
      throw ValidationError.invalidInput
    }
    var foods: [Snapshot] = []
    var totals = MacroTotals()
    for entry in entries {
      guard !entry.isDeleted, let food = entry.foodItem, !food.isDeleted,
        !food.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        entry.quantity.isFinite, entry.quantity > 0
      else { throw ValidationError.invalidInput }
      let macros = MacroTotals(
        calories: food.calories, protein: food.proteinGrams,
        carbs: food.carbGrams, fat: food.fatGrams)
      let baseline = [macros.calories, macros.protein, macros.carbs, macros.fat]
      let scaled = baseline.map { $0 * entry.quantity }
      guard baseline.allSatisfy({ $0.isFinite && $0 >= 0 }),
        scaled.allSatisfy({ $0.isFinite && $0 >= 0 })
      else { throw ValidationError.invalidInput }
      totals.calories += scaled[0]
      totals.protein += scaled[1]
      totals.carbs += scaled[2]
      totals.fat += scaled[3]
      guard [totals.calories, totals.protein, totals.carbs, totals.fat].allSatisfy(\.isFinite)
      else {
        throw ValidationError.invalidInput
      }
      foods.append(
        Snapshot(
          name: food.name, macros: macros, servingDescription: food.servingDescription,
          sourceType: food.sourceType, menuItem: food.menuItem,
          quantity: entry.quantity, meal: entry.mealType, note: entry.note))
    }
    return (foods, totals)
  }

  private static func resolveMenu(_ source: MenuItem?, in context: ModelContext) throws -> MenuItem?
  {
    guard let source else { return nil }
    guard !source.isDeleted else { throw ValidationError.invalidInput }
    if source.modelContext === context { return source }
    // Cross-context SwiftData relationships are unsafe. Reuse the same stored identity in this
    // context, or fail before insertion rather than adding/changing a source catalog object.
    let id = source.id
    var descriptor = FetchDescriptor<MenuItem>(predicate: #Predicate { $0.id == id })
    descriptor.fetchLimit = 2
    let matches = try context.fetch(descriptor)
    guard matches.count == 1 else { throw ValidationError.invalidInput }
    return matches[0]
  }
}
