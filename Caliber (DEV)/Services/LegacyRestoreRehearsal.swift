import CaliberDatabase
import CoreFoundation
import Foundation
import SwiftData

/// Results from rebuilding current models in a separate in-memory store.
/// No user store, file URL, cloud configuration or app context is accepted.
struct LegacyRestoreReport {
  let rehearsalID: UUID
  let restoredRows: [LegacySnapshotRow]
  var rowCount: Int { restoredRows.count }
  var entityCounts: [String: Int] {
    Dictionary(grouping: restoredRows, by: \.entity).mapValues(\.count)
  }
}

@MainActor
enum LegacyRestoreRehearsal {
  static var schema: Schema {
    Schema([
      FoodItem.self, Restaurant.self, MenuItem.self, MenuItemModifier.self,
      BuildableItemTemplate.self, BuildComponentCategory.self, BuildComponentOption.self,
      SavedMeal.self, SavedMealItem.self, DiaryEntry.self, WeightEntry.self,
      ProgressEntry.self, ProgressPhoto.self, Note.self, UserProfile.self,
    ])
  }

  /// The persisted archive supplies the input. Reconstruction always uses a new memory store.
  /// This proves the model mapping, not a disk migration, encrypted backup or live cutover.
  static func verify(
    _ rows: [LegacySnapshotRow], failAfter: Int? = nil
  ) throws -> LegacyRestoreReport {
    let expected = rows.sorted { ($0.entity, $0.id) < ($1.entity, $1.id) }
    let fields = try validatedFields(expected)
    let restored = try autoreleasepool {
      try rebuild(expected, fields: fields, failAfter: failAfter)
    }
    guard restored == expected else { throw FoundationStorageError.incompleteFixture }
    return LegacyRestoreReport(rehearsalID: UUID(), restoredRows: restored)
  }

  private static func key(_ entity: String, _ id: String) -> String { entity + "/" + id }

  private static let layouts: [String: String] = [
    "FoodItem":
      "name calories protein carbs fat servingDescription sourceType isSavedToLibrary menuItem",
    "Restaurant": "name menuItems buildableTemplates",
    "MenuItem": "name calories protein carbs fat category isCustom restaurant modifiers",
    "MenuItemModifier": "name calorieDelta proteinDelta carbDelta fatDelta menuItem",
    "BuildableItemTemplate": "name restaurant categories",
    "BuildComponentCategory": "name selectionType isRequired sortOrder template options",
    "BuildComponentOption": "name calories protein carbs fat supportsDouble category",
    "DiaryEntry":
      "dateReference mealType foodItem quantity note caloriesSnapshot proteinSnapshot carbsSnapshot fatSnapshot",
    "SavedMeal": "name items",
    "SavedMealItem": "quantity foodItem savedMeal",
    "WeightEntry": "dateReference enteredValue enteredUnit weightKG progressEntry",
    "ProgressEntry": "dateReference notes weightEntry photos",
    "ProgressPhoto": "imageDataBase64 sortOrder progressEntry",
    "Note": "dateReference text linkedDiaryEntry",
    "UserProfile":
      "heightInInches startingWeight activityLevel dailyCalorieGoal proteinGoal carbGoal fatGoal",
  ]

  private static func validatedFields(_ rows: [LegacySnapshotRow]) throws -> [String: Fields] {
    var result: [String: Fields] = [:]
    let keys = Set(rows.map { key($0.entity, $0.id) })
    guard keys.count == rows.count else { throw FoundationStorageError.invalidFixture }
    for row in rows {
      guard UUID(uuidString: row.id)?.uuidString == row.id,
        let layout = layouts[row.entity],
        let object = try JSONSerialization.jsonObject(with: row.payload) as? [String: Any],
        Set(object.keys) == Set(layout.split(separator: " ").map(String.init))
          || (row.entity == "SavedMeal"
            && Set(object.keys)
              == Set([
                "name", "items", "payloadVersion", "servings", "cookedYieldGrams", "rawBatchGrams",
              ]))
      else { throw FoundationStorageError.invalidFixture }
      let values = Fields(object)
      if row.entity == "SavedMeal" { _ = try savedMealMetadata(values) }
      // Require the sidecar links to agree with the actual fields before creating any store.
      let references = try links(row.entity, values)
      guard references.sorted(by: referenceOrder) == row.references.sorted(by: referenceOrder),
        Set(references.map { key($0.entity, $0.id) }).count == references.count,
        references.allSatisfy({ keys.contains(key($0.entity, $0.id)) })
      else { throw FoundationStorageError.invalidFixture }
      result[key(row.entity, row.id)] = values
    }
    return result
  }

  private static func savedMealMetadata(_ fields: Fields) throws -> (
    servings: Double, cooked: Double?, raw: Double?
  ) {
    if fields.values["payloadVersion"] == nil { return (1, nil, nil) }
    guard try fields.integer("payloadVersion") == 2 else {
      throw FoundationStorageError.invalidFixture
    }
    let servings = try fields.number("servings")
    let cooked =
      fields.values["cookedYieldGrams"] is NSNull ? nil : try fields.number("cookedYieldGrams")
    let raw = fields.values["rawBatchGrams"] is NSNull ? nil : try fields.number("rawBatchGrams")
    guard servings > 0, cooked.map({ $0 > 0 }) ?? true, raw.map({ $0 > 0 }) ?? true,
      servings != 1 || cooked != nil || raw != nil
    else { throw FoundationStorageError.invalidFixture }
    return (servings, cooked, raw)
  }

  private static func referenceOrder(_ a: LegacyReference, _ b: LegacyReference) -> Bool {
    (a.entity, a.id) < (b.entity, b.id)
  }

  private static func links(_ entity: String, _ fields: Fields) throws -> [LegacyReference] {
    var result: [LegacyReference] = []
    func one(_ field: String, _ target: String) throws {
      if let id = try fields.optionalID(field) { result.append(LegacyReference(target, id)) }
    }
    func many(_ field: String, _ target: String) throws {
      result += try fields.ids(field).map { LegacyReference(target, $0) }
    }
    switch entity {
    case "FoodItem": try one("menuItem", "MenuItem")
    case "Restaurant":
      try many("menuItems", "MenuItem")
      try many("buildableTemplates", "BuildableItemTemplate")
    case "MenuItem":
      try one("restaurant", "Restaurant")
      try many("modifiers", "MenuItemModifier")
    case "MenuItemModifier": try one("menuItem", "MenuItem")
    case "BuildableItemTemplate":
      try one("restaurant", "Restaurant")
      try many("categories", "BuildComponentCategory")
    case "BuildComponentCategory":
      try one("template", "BuildableItemTemplate")
      try many("options", "BuildComponentOption")
    case "BuildComponentOption": try one("category", "BuildComponentCategory")
    case "DiaryEntry": try one("foodItem", "FoodItem")
    case "SavedMeal": try many("items", "SavedMealItem")
    case "SavedMealItem":
      try one("foodItem", "FoodItem")
      try one("savedMeal", "SavedMeal")
    case "WeightEntry": try one("progressEntry", "ProgressEntry")
    case "ProgressEntry":
      try one("weightEntry", "WeightEntry")
      try many("photos", "ProgressPhoto")
    case "ProgressPhoto": try one("progressEntry", "ProgressEntry")
    case "Note": try one("linkedDiaryEntry", "DiaryEntry")
    case "UserProfile": break
    default: throw FoundationStorageError.invalidFixture
    }
    return result
  }

  private static func rebuild(
    _ rows: [LegacySnapshotRow], fields: [String: Fields], failAfter: Int?
  ) throws -> [LegacySnapshotRow] {
    let container = try ModelContainer(
      for: schema,
      configurations: [
        ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
      ])
    // Supported iOS 17 API; only this newly created memory container is torn down.
    defer { container.deleteAllData() }
    let context = ModelContext(container)
    context.autosaveEnabled = false
    var models: [String: any PersistentModel] = [:]
    // Original initializers require a food even though saved relationships can be nil.
    // This transient object is never inserted and is detached before insertion of an orphan.
    let placeholder = FoodItem(
      name: "", calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0, servingDescription: "")
    do {
      for (index, row) in rows.enumerated() {
        if failAfter == index { throw FoundationStorageError.unavailable }
        guard let f = fields[key(row.entity, row.id)], let id = UUID(uuidString: row.id)
        else { throw FoundationStorageError.invalidFixture }
        let model: any PersistentModel
        switch row.entity {
        case "FoodItem":
          let x = FoodItem(
            name: try f.string("name"), calories: try f.number("calories"),
            proteinGrams: try f.number("protein"), carbGrams: try f.number("carbs"),
            fatGrams: try f.number("fat"), servingDescription: try f.string("servingDescription"),
            sourceType: try f.enumValue("sourceType", FoodSourceType.self),
            isSavedToLibrary: try f.boolean("isSavedToLibrary"))
          x.id = id
          model = x
        case "Restaurant":
          let x = Restaurant(name: try f.string("name"))
          x.id = id
          model = x
        case "MenuItem":
          let x = MenuItem(
            name: try f.string("name"), baseCalories: try f.number("calories"),
            baseProtein: try f.number("protein"), baseCarbs: try f.number("carbs"),
            baseFat: try f.number("fat"), category: try f.enumValue("category", MenuCategory.self),
            isCustom: try f.boolean("isCustom"))
          x.id = id
          model = x
        case "MenuItemModifier":
          let x = MenuItemModifier(
            name: try f.string("name"), calorieDelta: try f.number("calorieDelta"),
            proteinDelta: try f.number("proteinDelta"), carbDelta: try f.number("carbDelta"),
            fatDelta: try f.number("fatDelta"))
          x.id = id
          model = x
        case "BuildableItemTemplate":
          let x = BuildableItemTemplate(name: try f.string("name"))
          x.id = id
          model = x
        case "BuildComponentCategory":
          let x = BuildComponentCategory(
            name: try f.string("name"),
            selectionType: try f.enumValue("selectionType", SelectionType.self),
            isRequired: try f.boolean("isRequired"), sortOrder: try f.integer("sortOrder"))
          x.id = id
          model = x
        case "BuildComponentOption":
          let x = BuildComponentOption(
            name: try f.string("name"), calories: try f.number("calories"),
            protein: try f.number("protein"), carbs: try f.number("carbs"),
            fat: try f.number("fat"),
            supportsDouble: try f.boolean("supportsDouble"))
          x.id = id
          model = x
        case "DiaryEntry":
          let x = DiaryEntry(
            date: try f.date(), mealType: try f.enumValue("mealType", MealType.self),
            foodItem: placeholder, quantity: try f.number("quantity"),
            note: try f.optionalString("note"))
          x.foodItem = nil
          // These are derived from food + quantity; final round-trip checks them without overriding.
          for field in ["caloriesSnapshot", "proteinSnapshot", "carbsSnapshot", "fatSnapshot"] {
            _ = try f.number(field)
          }
          x.id = id
          model = x
        case "SavedMeal":
          let metadata = try savedMealMetadata(f)
          let x = SavedMeal(
            name: try f.string("name"), servings: metadata.servings,
            cookedYieldGrams: metadata.cooked, rawBatchGrams: metadata.raw)
          x.id = id
          model = x
        case "SavedMealItem":
          let x = SavedMealItem(foodItem: placeholder, quantity: try f.number("quantity"))
          x.foodItem = nil
          x.id = id
          model = x
        case "WeightEntry":
          guard try f.string("enteredUnit") == "lb" else {
            throw FoundationStorageError.invalidFixture
          }
          let entered = try f.number("enteredValue")
          guard try f.number("weightKG") == entered * 0.45359237 else {
            throw FoundationStorageError.invalidFixture
          }
          let x = WeightEntry(date: try f.date(), weightInPounds: entered)
          x.id = id
          model = x
        case "ProgressEntry":
          let x = ProgressEntry(date: try f.date(), notes: try f.string("notes"))
          x.id = id
          model = x
        case "ProgressPhoto":
          let encoded = try f.string("imageDataBase64")
          guard let bytes = Data(base64Encoded: encoded), bytes.base64EncodedString() == encoded
          else { throw FoundationStorageError.invalidFixture }
          model = ProgressPhoto(id: id, imageData: bytes, sortOrder: try f.integer("sortOrder"))
        case "Note":
          let x = Note(date: try f.date(), text: try f.string("text"))
          x.id = id
          model = x
        case "UserProfile":
          let x = UserProfile(
            heightInInches: try f.number("heightInInches"),
            startingWeight: try f.number("startingWeight"),
            activityLevel: try f.enumValue("activityLevel", ActivityLevel.self),
            dailyCalorieGoal: try f.number("dailyCalorieGoal"),
            proteinGoal: try f.number("proteinGoal"),
            carbGoal: try f.number("carbGoal"), fatGoal: try f.number("fatGoal"))
          x.id = id
          model = x
        default: throw FoundationStorageError.invalidFixture
        }
        models[key(row.entity, row.id)] = model
        context.insert(model)
      }
      // All objects exist before linking, so forward references and cycles are preserved.
      func one<T: PersistentModel>(_ id: String?, _ entity: String, _: T.Type) throws -> T? {
        guard let id else { return nil }
        guard let model = models[key(entity, id)] as? T else {
          throw FoundationStorageError.invalidFixture
        }
        return model
      }
      func many<T: PersistentModel>(_ ids: [String], _ entity: String, _ type: T.Type) throws -> [T]
      {
        try ids.map {
          guard let model = try one($0, entity, type) else {
            throw FoundationStorageError.invalidFixture
          }
          return model
        }
      }
      for row in rows {
        guard let f = fields[key(row.entity, row.id)], let model = models[key(row.entity, row.id)]
        else { throw FoundationStorageError.invalidFixture }
        switch model {
        case let x as FoodItem:
          x.menuItem = try one(f.optionalID("menuItem"), "MenuItem", MenuItem.self)
        case let x as Restaurant:
          x.menuItems = try many(f.ids("menuItems"), "MenuItem", MenuItem.self)
          x.buildableTemplates = try many(
            f.ids("buildableTemplates"), "BuildableItemTemplate", BuildableItemTemplate.self)
        case let x as MenuItem:
          x.restaurant = try one(f.optionalID("restaurant"), "Restaurant", Restaurant.self)
          x.modifiers = try many(f.ids("modifiers"), "MenuItemModifier", MenuItemModifier.self)
        case let x as MenuItemModifier:
          x.menuItem = try one(f.optionalID("menuItem"), "MenuItem", MenuItem.self)
        case let x as BuildableItemTemplate:
          x.restaurant = try one(f.optionalID("restaurant"), "Restaurant", Restaurant.self)
          x.categories = try many(
            f.ids("categories"), "BuildComponentCategory", BuildComponentCategory.self)
        case let x as BuildComponentCategory:
          x.template = try one(
            f.optionalID("template"), "BuildableItemTemplate", BuildableItemTemplate.self)
          x.options = try many(f.ids("options"), "BuildComponentOption", BuildComponentOption.self)
        case let x as BuildComponentOption:
          x.category = try one(
            f.optionalID("category"), "BuildComponentCategory", BuildComponentCategory.self)
        case let x as DiaryEntry:
          x.foodItem = try one(f.optionalID("foodItem"), "FoodItem", FoodItem.self)
        case let x as SavedMeal:
          x.items = try many(f.ids("items"), "SavedMealItem", SavedMealItem.self)
        case let x as SavedMealItem:
          x.foodItem = try one(f.optionalID("foodItem"), "FoodItem", FoodItem.self)
          x.savedMeal = try one(f.optionalID("savedMeal"), "SavedMeal", SavedMeal.self)
        case let x as WeightEntry:
          x.progressEntry = try one(
            f.optionalID("progressEntry"), "ProgressEntry", ProgressEntry.self)
        case let x as ProgressEntry:
          x.weightEntry = try one(f.optionalID("weightEntry"), "WeightEntry", WeightEntry.self)
          x.photos = try many(f.ids("photos"), "ProgressPhoto", ProgressPhoto.self)
        case let x as ProgressPhoto:
          x.progressEntry = try one(
            f.optionalID("progressEntry"), "ProgressEntry", ProgressEntry.self)
        case let x as Note:
          x.linkedDiaryEntry = try one(
            f.optionalID("linkedDiaryEntry"), "DiaryEntry", DiaryEntry.self)
        case is UserProfile: break
        default: throw FoundationStorageError.invalidFixture
        }
      }
      try context.save()
      // Read through another context: return values only, never models attached to the source.
      let verificationContext = ModelContext(container)
      verificationContext.autosaveEnabled = false
      let restored = try LegacySnapshotAdapter.capture(verificationContext)
      guard restored == rows else { throw FoundationStorageError.incompleteFixture }
      return restored
    } catch {
      context.rollback()
      throw error
    }
  }

  private struct Fields {
    let values: [String: Any]
    init(_ values: [String: Any]) { self.values = values }
    func string(_ field: String) throws -> String {
      guard let value = values[field] as? String else {
        throw FoundationStorageError.invalidFixture
      }
      return value
    }
    func optionalString(_ field: String) throws -> String? {
      if values[field] is NSNull { return nil }
      return try string(field)
    }
    func number(_ field: String) throws -> Double {
      guard let value = values[field] as? NSNumber,
        CFGetTypeID(value) != CFBooleanGetTypeID(), value.doubleValue.isFinite
      else { throw FoundationStorageError.invalidFixture }
      return value.doubleValue
    }
    func integer(_ field: String) throws -> Int {
      guard let number = values[field] as? NSNumber,
        CFGetTypeID(number) != CFBooleanGetTypeID()
      else { throw FoundationStorageError.invalidFixture }
      // Preserve all Int bits; converting an Int64 through Double can round large ranks.
      if let exact = Int(number.stringValue) { return exact }
      guard let value = Int(exactly: number.doubleValue) else {
        throw FoundationStorageError.invalidFixture
      }
      return value
    }
    func boolean(_ field: String) throws -> Bool {
      guard let value = values[field] as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID()
      else { throw FoundationStorageError.invalidFixture }
      return value.boolValue
    }
    func enumValue<T: RawRepresentable>(_ field: String, _: T.Type) throws -> T
    where T.RawValue == String {
      guard let value = T(rawValue: try string(field)) else {
        throw FoundationStorageError.invalidFixture
      }
      return value
    }
    func optionalID(_ field: String) throws -> String? {
      guard let text = try optionalString(field) else { return nil }
      guard UUID(uuidString: text)?.uuidString == text else {
        throw FoundationStorageError.invalidFixture
      }
      return text
    }
    func ids(_ field: String) throws -> [String] {
      guard let ids = values[field] as? [String], Set(ids).count == ids.count,
        ids.allSatisfy({ UUID(uuidString: $0)?.uuidString == $0 })
      else { throw FoundationStorageError.invalidFixture }
      return ids
    }
    func date() throws -> Date { Date(timeIntervalSinceReferenceDate: try number("dateReference")) }
  }
}
