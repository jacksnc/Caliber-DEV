import CaliberDatabase
import Foundation
import SwiftData

/// Reads only public model properties. Never opens SwiftData's private SQLite files.
/// This rehearsal adapter is exercised against fixtures; live storage is not switched.
@MainActor
enum LegacySnapshotAdapter {
  static func capture(_ context: ModelContext) throws -> [LegacySnapshotRow] {
    // Snapshot only a fully saved boundary. Do not silently save a user's unrelated draft.
    guard !context.hasChanges else { throw FoundationStorageError.invalidFixture }
    var result: [LegacySnapshotRow] = []
    func row(
      _ entity: String, _ id: UUID, _ fields: [String: Any], _ references: [LegacyReference] = []
    ) throws {
      result.append(
        LegacySnapshotRow(
          entity: entity, id: id.uuidString,
          payload: try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]),
          references: references.sorted { ($0.entity, $0.id) < ($1.entity, $1.id) }))
    }
    func ref(_ entity: String, _ id: UUID?) -> [LegacyReference] {
      id.map { [LegacyReference(entity, $0.uuidString)] } ?? []
    }
    func value(_ id: UUID?) -> Any { id?.uuidString as Any? ?? NSNull() }
    for x in try context.fetch(FetchDescriptor<FoodItem>()) {
      try row(
        "FoodItem", x.id,
        [
          "name": x.name, "calories": x.calories, "protein": x.proteinGrams, "carbs": x.carbGrams,
          "fat": x.fatGrams, "servingDescription": x.servingDescription,
          "sourceType": x.sourceType.rawValue, "isSavedToLibrary": x.isSavedToLibrary,
          "menuItem": value(x.menuItem?.id),
        ], ref("MenuItem", x.menuItem?.id))
    }
    for x in try context.fetch(FetchDescriptor<Restaurant>()) {
      try row(
        "Restaurant", x.id,
        [
          "name": x.name, "menuItems": x.menuItems.map { $0.id.uuidString }.sorted(),
          "buildableTemplates": x.buildableTemplates.map { $0.id.uuidString }.sorted(),
        ],
        x.menuItems.flatMap { ref("MenuItem", $0.id) }
          + x.buildableTemplates.flatMap { ref("BuildableItemTemplate", $0.id) })
    }
    for x in try context.fetch(FetchDescriptor<MenuItem>()) {
      try row(
        "MenuItem", x.id,
        [
          "name": x.name, "calories": x.baseCalories, "protein": x.baseProtein,
          "carbs": x.baseCarbs, "fat": x.baseFat, "category": x.category.rawValue,
          "isCustom": x.isCustom, "restaurant": value(x.restaurant?.id),
          "modifiers": x.modifiers.map { $0.id.uuidString }.sorted(),
        ],
        ref("Restaurant", x.restaurant?.id) + x.modifiers.flatMap { ref("MenuItemModifier", $0.id) }
      )
    }
    for x in try context.fetch(FetchDescriptor<MenuItemModifier>()) {
      try row(
        "MenuItemModifier", x.id,
        [
          "name": x.name, "calorieDelta": x.calorieDelta, "proteinDelta": x.proteinDelta,
          "carbDelta": x.carbDelta, "fatDelta": x.fatDelta, "menuItem": value(x.menuItem?.id),
        ], ref("MenuItem", x.menuItem?.id))
    }
    for x in try context.fetch(FetchDescriptor<BuildableItemTemplate>()) {
      try row(
        "BuildableItemTemplate", x.id,
        [
          "name": x.name, "restaurant": value(x.restaurant?.id),
          "categories": x.categories.map { $0.id.uuidString }.sorted(),
        ],
        ref("Restaurant", x.restaurant?.id)
          + x.categories.flatMap { ref("BuildComponentCategory", $0.id) })
    }
    for x in try context.fetch(FetchDescriptor<BuildComponentCategory>()) {
      try row(
        "BuildComponentCategory", x.id,
        [
          "name": x.name, "selectionType": x.selectionType.rawValue, "isRequired": x.isRequired,
          "sortOrder": x.sortOrder, "template": value(x.template?.id),
          "options": x.options.map { $0.id.uuidString }.sorted(),
        ],
        ref("BuildableItemTemplate", x.template?.id)
          + x.options.flatMap { ref("BuildComponentOption", $0.id) })
    }
    for x in try context.fetch(FetchDescriptor<BuildComponentOption>()) {
      try row(
        "BuildComponentOption", x.id,
        [
          "name": x.name, "calories": x.calories, "protein": x.protein, "carbs": x.carbs,
          "fat": x.fat, "supportsDouble": x.supportsDouble, "category": value(x.category?.id),
        ], ref("BuildComponentCategory", x.category?.id))
    }
    for x in try context.fetch(FetchDescriptor<DiaryEntry>()) {
      try row(
        "DiaryEntry", x.id,
        [
          "dateReference": x.date.timeIntervalSinceReferenceDate, "mealType": x.mealType.rawValue,
          "foodItem": value(x.foodItem?.id), "quantity": x.quantity,
          "note": x.note as Any? ?? NSNull(), "caloriesSnapshot": x.calories,
          "proteinSnapshot": x.protein, "carbsSnapshot": x.carbs, "fatSnapshot": x.fat,
        ], ref("FoodItem", x.foodItem?.id))
    }
    for x in try context.fetch(FetchDescriptor<SavedMeal>()) {
      guard x.servings.isFinite, x.servings > 0,
        [x.cookedYieldGrams, x.rawBatchGrams].compactMap({ $0 }).allSatisfy({
          $0.isFinite && $0 > 0
        })
      else { throw FoundationStorageError.invalidFixture }
      var fields: [String: Any] = [
        "name": x.name, "items": x.items.map { $0.id.uuidString }.sorted(),
      ]
      // Default metadata keeps the exact original payload. Old archives do not acquire new bytes.
      if x.servings != 1 || x.cookedYieldGrams != nil || x.rawBatchGrams != nil {
        fields["payloadVersion"] = 2
        fields["servings"] = x.servings
        fields["cookedYieldGrams"] = x.cookedYieldGrams as Any? ?? NSNull()
        fields["rawBatchGrams"] = x.rawBatchGrams as Any? ?? NSNull()
      }
      try row(
        "SavedMeal", x.id, fields,
        x.items.flatMap { ref("SavedMealItem", $0.id) })
    }
    for x in try context.fetch(FetchDescriptor<SavedMealItem>()) {
      try row(
        "SavedMealItem", x.id,
        [
          "quantity": x.quantity, "foodItem": value(x.foodItem?.id),
          "savedMeal": value(x.savedMeal?.id),
        ], ref("FoodItem", x.foodItem?.id) + ref("SavedMeal", x.savedMeal?.id))
    }
    for x in try context.fetch(FetchDescriptor<WeightEntry>()) {
      try row(
        "WeightEntry", x.id,
        [
          "dateReference": x.date.timeIntervalSinceReferenceDate, "enteredValue": x.weightInPounds,
          "enteredUnit": "lb", "weightKG": x.weightInPounds * 0.45359237,
          "progressEntry": value(x.progressEntry?.id),
        ], ref("ProgressEntry", x.progressEntry?.id))
    }
    for x in try context.fetch(FetchDescriptor<ProgressEntry>()) {
      try row(
        "ProgressEntry", x.id,
        [
          "dateReference": x.date.timeIntervalSinceReferenceDate, "notes": x.notes,
          "weightEntry": value(x.weightEntry?.id),
          "photos": x.sortedPhotos.map { $0.id.uuidString },
        ], ref("WeightEntry", x.weightEntry?.id) + x.photos.flatMap { ref("ProgressPhoto", $0.id) })
    }
    for x in try context.fetch(FetchDescriptor<ProgressPhoto>()) {
      try row(
        "ProgressPhoto", x.id,
        [
          "imageDataBase64": x.imageData.base64EncodedString(), "sortOrder": x.sortOrder,
          "progressEntry": value(x.progressEntry?.id),
        ], ref("ProgressEntry", x.progressEntry?.id))
    }
    for x in try context.fetch(FetchDescriptor<Note>()) {
      try row(
        "Note", x.id,
        [
          "dateReference": x.date.timeIntervalSinceReferenceDate, "text": x.text,
          "linkedDiaryEntry": value(x.linkedDiaryEntry?.id),
        ], ref("DiaryEntry", x.linkedDiaryEntry?.id))
    }
    for x in try context.fetch(FetchDescriptor<UserProfile>()) {
      try row(
        "UserProfile", x.id,
        [
          "heightInInches": x.heightInInches, "startingWeight": x.startingWeight,
          "activityLevel": x.activityLevel.rawValue, "dailyCalorieGoal": x.dailyCalorieGoal,
          "proteinGoal": x.proteinGoal, "carbGoal": x.carbGoal, "fatGoal": x.fatGoal,
        ])
    }
    return result.sorted { ($0.entity, $0.id) < ($1.entity, $1.id) }
  }
}
