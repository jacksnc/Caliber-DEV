import Foundation
import SwiftData

@MainActor
enum RecipeEditor {
  enum InputError: LocalizedError {
    case invalidName, invalidIngredient, missingFood
    var errorDescription: String? {
      switch self {
      case .invalidName: "Enter a recipe or meal name with 1–200 characters."
      case .invalidIngredient: "Each ingredient needs a name, a serving and valid nutrition."
      case .missingFood: "An ingredient is missing its food. Edit the recipe before logging it."
      }
    }
  }

  static func ingredients(for meal: SavedMeal) throws -> [RecipeIngredientDraft] {
    try meal.items.map { item in
      guard let food = item.foodItem else { throw InputError.missingFood }
      return RecipeIngredientDraft(
        id: item.id, name: food.name, servingDescription: food.servingDescription,
        totals: MacroTotals(
          calories: food.calories, protein: food.proteinGrams,
          carbs: food.carbGrams, fat: food.fatGrams),
        quantity: item.quantity, sourceType: food.sourceType)
    }
  }

  static func batch(for meal: SavedMeal) throws -> RecipeBatchNutrition {
    try batch(
      ingredients: ingredients(for: meal), servings: meal.servings,
      cookedYieldGrams: meal.cookedYieldGrams, rawBatchGrams: meal.rawBatchGrams)
  }

  static func batch(
    ingredients: [RecipeIngredientDraft], servings: Double,
    cookedYieldGrams: Double?, rawBatchGrams: Double?
  ) throws -> RecipeBatchNutrition {
    guard Set(ingredients.map(\.id)).count == ingredients.count,
      ingredients.allSatisfy({
        let name = $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let serving = $0.servingDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return (1...200).contains(name.count) && (1...2_000).contains(serving.count)
      })
    else { throw InputError.invalidIngredient }
    return try RecipeBatchNutrition(
      ingredients: ingredients.map {
        RecipeNutritionIngredient(totals: $0.totals, quantity: $0.quantity)
      },
      servings: servings, cookedYieldGrams: cookedYieldGrams, rawBatchGrams: rawBatchGrams)
  }

  @discardableResult
  static func save(
    meal: SavedMeal? = nil, name: String, ingredients: [RecipeIngredientDraft],
    servings: Double, cookedYieldGrams: Double?, rawBatchGrams: Double?,
    in context: ModelContext, persist: (ModelContext) throws -> Void = { try $0.save() }
  ) throws -> SavedMeal {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard (1...200).contains(name.count) else { throw InputError.invalidName }
    _ = try batch(
      ingredients: ingredients, servings: servings,
      cookedYieldGrams: cookedYieldGrams, rawBatchGrams: rawBatchGrams)
    let target: SavedMeal
    if let meal {
      target = try currentMeal(meal, in: context)
    } else {
      target = SavedMeal(name: name)
    }
    let oldName = target.name
    let oldServings = target.servings
    let oldCooked = target.cookedYieldGrams
    let oldRaw = target.rawBatchGrams
    let oldItems = target.items
    let oldLinks = oldItems.map { ($0, $0.foodItem) }
    let disposableFoods = try unsharedFoods(for: oldItems, in: context)
    let foods = ingredients.map { ingredient in
      FoodItem(
        name: ingredient.name, calories: ingredient.totals.calories,
        proteinGrams: ingredient.totals.protein, carbGrams: ingredient.totals.carbs,
        fatGrams: ingredient.totals.fat, servingDescription: ingredient.servingDescription,
        sourceType: ingredient.sourceType)
    }
    let items = zip(foods, ingredients).map {
      SavedMealItem(foodItem: $0.0, quantity: $0.1.quantity)
    }
    if meal == nil { context.insert(target) }
    for food in foods { context.insert(food) }
    for item in items { context.insert(item) }
    target.name = name
    target.servings = servings
    target.cookedYieldGrams = cookedYieldGrams
    target.rawBatchGrams = rawBatchGrams
    target.items = items
    for item in oldItems { context.delete(item) }
    for food in disposableFoods { context.delete(food) }
    do {
      try persist(context)
      return target
    } catch {
      // Restore only this attempted edit. Unrelated pending changes survive.
      target.items = []
      for item in items { context.delete(item) }
      for food in foods { context.delete(food) }
      if meal == nil {
        context.delete(target)
      } else {
        for food in disposableFoods { context.insert(food) }
        for item in oldItems { context.insert(item) }
        context.processPendingChanges()
        target.name = oldName
        target.servings = oldServings
        target.cookedYieldGrams = oldCooked
        target.rawBatchGrams = oldRaw
        for (item, food) in oldLinks {
          item.savedMeal = nil
          item.foodItem = food
        }
        target.items = oldItems
      }
      throw error
    }
  }

  static func delete(
    meal: SavedMeal, in context: ModelContext,
    persist: (ModelContext) throws -> Void = { try $0.save() }
  ) throws {
    // A failed SwiftData save can detach the original object while the restored
    // row is available under the same ID. Resolve it again before a retry.
    let target = try currentMeal(meal, in: context)
    let items = target.items
    let links = items.map { ($0, $0.foodItem) }
    let foods = try unsharedFoods(for: items, in: context)
    context.delete(target)
    for food in foods { context.delete(food) }
    do { try persist(context) } catch {
      context.insert(target)
      for food in foods { context.insert(food) }
      for item in items { context.insert(item) }
      context.processPendingChanges()
      for (item, food) in links {
        item.savedMeal = nil
        item.foodItem = food
      }
      target.items = items
      throw error
    }
  }

  private static func currentMeal(_ meal: SavedMeal, in context: ModelContext) throws -> SavedMeal {
    let mealID = meal.id
    var descriptor = FetchDescriptor<SavedMeal>(predicate: #Predicate { $0.id == mealID })
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first ?? meal
  }

  /// Old meals may reference shared or library foods. Delete a food snapshot
  /// only when no diary or other saved meal uses it; never delete a source menu.
  private static func unsharedFoods(for items: [SavedMealItem], in context: ModelContext) throws
    -> [FoodItem]
  {
    let removedIDs = Set(items.map(\.id))
    var seen: Set<UUID> = []
    return try items.compactMap { item in
      guard let food = item.foodItem, !food.isSavedToLibrary, seen.insert(food.id).inserted else {
        return nil
      }
      let id = food.id
      var logs = FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.foodItem?.id == id })
      logs.fetchLimit = 1
      guard try context.fetch(logs).isEmpty else { return nil }
      let references = FetchDescriptor<SavedMealItem>(
        predicate: #Predicate { $0.foodItem?.id == id })
      guard try context.fetch(references).allSatisfy({ removedIDs.contains($0.id) }) else {
        return nil
      }
      return food
    }
  }
}

@MainActor
enum RecipeLogger {
  @discardableResult
  static func log(
    meal: SavedMeal, amount: Double, unit: RecipePortionUnit,
    override: MacroTotals? = nil, date: Date, mealType: MealType,
    in context: ModelContext, persist: (ModelContext) throws -> Void = { try $0.save() }
  ) throws -> [DiaryEntry] {
    let batch = try RecipeEditor.batch(for: meal)
    let portion = try batch.portion(amount: amount, unit: unit)
    let fraction = try batch.batchFraction(amount: amount, unit: unit)
    guard date.timeIntervalSinceReferenceDate.isFinite, (override ?? portion).isValid else {
      throw RecipeEditor.InputError.invalidIngredient
    }
    var foods: [FoodItem] = []
    var entries: [DiaryEntry] = []
    if let override {
      let food = FoodItem(
        name: meal.name + " (edited)", calories: override.calories,
        proteinGrams: override.protein, carbGrams: override.carbs, fatGrams: override.fat,
        servingDescription:
          "\(NutritionInput.format(amount, locale: Locale(identifier: "en_US"))) \(unit.displayName) · \(meal.name) · personal values"
      )
      foods = [food]
      entries = [DiaryEntry(date: date, mealType: mealType, foodItem: food)]
    } else {
      for item in meal.items {
        guard let source = item.foodItem else { throw RecipeEditor.InputError.missingFood }
        let quantity = item.quantity * fraction
        guard quantity.isFinite, quantity > 0 else {
          throw RecipeEditor.InputError.invalidIngredient
        }
        let food = FoodItem(
          name: source.name, calories: source.calories, proteinGrams: source.proteinGrams,
          carbGrams: source.carbGrams, fatGrams: source.fatGrams,
          servingDescription: source.servingDescription + " · " + meal.name,
          sourceType: source.sourceType)
        foods.append(food)
        entries.append(
          DiaryEntry(date: date, mealType: mealType, foodItem: food, quantity: quantity))
      }
    }
    // All validation happens before the first insertion; one save covers the whole portion.
    for food in foods { context.insert(food) }
    for entry in entries { context.insert(entry) }
    do {
      try persist(context)
      return entries
    } catch {
      for entry in entries { context.delete(entry) }
      for food in foods { context.delete(food) }
      throw error
    }
  }
}
