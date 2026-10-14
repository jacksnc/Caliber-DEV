import Foundation
import SwiftData
import Testing

@testable import Caliber__DEV_

@MainActor
@Suite("Repeat diary entries")
struct DiaryRepeatLoggerTests {
  private let sourceDate = Date(timeIntervalSince1970: 1_700_000_000.125)
  private let destinationDate = Date(timeIntervalSince1970: 1_700_123_456.875)

  private func container() throws -> ModelContainer {
    let schema = Schema([
      FoodItem.self, DiaryEntry.self, Restaurant.self, MenuItem.self, MenuItemModifier.self,
      BuildableItemTemplate.self, BuildComponentCategory.self, BuildComponentOption.self,
      SavedMeal.self, SavedMealItem.self,
    ])
    return try ModelContainer(
      for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
  }

  private func food(_ name: String = "Original food") -> FoodItem {
    FoodItem(
      name: name, calories: 201.25, proteinGrams: 30.5, carbGrams: 40.25, fatGrams: 7.125,
      servingDescription: "Original fractional serving", sourceType: .restaurantMenuItem,
      isSavedToLibrary: true)
  }

  private func menu() -> MenuItem {
    MenuItem(
      name: "Original menu item", baseCalories: 250, baseProtein: 35, baseCarbs: 45,
      baseFat: 10, category: .entree, isCustom: true)
  }

  @Test("Preview and copies preserve baseline portions, notes and independent food identities")
  func copiesPreserveEditableSnapshots() throws {
    let container = try container()
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let originalFood = food("  Exact original name  ")
    let originalMenu = menu()
    originalFood.menuItem = originalMenu
    let first = DiaryEntry(
      date: sourceDate, mealType: .dinner, foodItem: originalFood, quantity: 1.25,
      note: "  Exact original note  ")
    let second = DiaryEntry(
      date: sourceDate, mealType: .breakfast, foodItem: originalFood, quantity: 0.5)
    let saved = SavedMealItem(foodItem: originalFood, quantity: 2.25)
    for model in [originalFood as any PersistentModel, originalMenu, first, second, saved] {
      context.insert(model)
    }
    try context.save()

    let expected = MacroTotals(
      calories: 352.1875, protein: 53.375, carbs: 70.4375, fat: 12.46875)
    #expect(try DiaryRepeatLogger.preview(entries: [first, second]) == expected)
    let copies = try DiaryRepeatLogger.copy(
      entries: [first, second], to: destinationDate, in: context)
    #expect(copies.count == 2)
    #expect(MacroCalculator.totals(for: copies) == expected)
    #expect(copies[0].mealType == .dinner && copies[1].mealType == .breakfast)
    #expect(copies.allSatisfy { $0.date == destinationDate })
    #expect(copies[0].quantity == 1.25 && copies[1].quantity == 0.5)
    #expect(copies[0].note == first.note && copies[1].note == nil)
    #expect(Set(copies.map(\.id)).count == 2)
    #expect(!copies.contains { $0.id == first.id || $0.id == second.id })
    let copiedFoods = try copies.map { try #require($0.foodItem) }
    #expect(Set(copiedFoods.map(\.id)).count == 2)
    #expect(copiedFoods.allSatisfy { $0.id != originalFood.id && !$0.isSavedToLibrary })
    for copied in copiedFoods {
      #expect(copied.name == "  Exact original name  ")
      #expect(copied.calories == 201.25 && copied.proteinGrams == 30.5)
      #expect(copied.carbGrams == 40.25 && copied.fatGrams == 7.125)
      #expect(copied.servingDescription == originalFood.servingDescription)
      #expect(copied.sourceType == .restaurantMenuItem)
      #expect(copied.menuItem?.id == originalMenu.id)
    }
    #expect(first.foodItem?.id == originalFood.id && second.foodItem?.id == originalFood.id)
    #expect(first.date == sourceDate && second.date == sourceDate)
    #expect(originalFood.isSavedToLibrary)
    #expect(originalMenu.baseCalories == 250)
    #expect(saved.foodItem?.id == originalFood.id && saved.quantity == 2.25)

    // Later changes to a source or to one repeated entry cannot alter the other copies.
    originalFood.name = "Changed library name"
    originalFood.calories = 999
    originalMenu.baseCalories = 888
    copiedFoods[0].proteinGrams = 1.25
    try context.save()
    #expect(copies[0].calories == 251.5625)
    #expect(copies[1].calories == 100.625 && copies[1].protein == 15.25)
    let reloadedContext = ModelContext(container)
    let reloaded = try reloadedContext.fetch(FetchDescriptor<DiaryEntry>())
    let reloadedFirst = try #require(reloaded.first { $0.id == copies[0].id })
    let reloadedSecond = try #require(reloaded.first { $0.id == copies[1].id })
    #expect(reloadedFirst.foodItem?.name == "  Exact original name  ")
    #expect(reloadedFirst.protein == 1.5625 && reloadedSecond.protein == 15.25)
    #expect(reloadedFirst.date == destinationDate && reloadedFirst.note == first.note)
    #expect(reloadedSecond.mealType == .breakfast)
    #expect(try reloadedContext.fetch(FetchDescriptor<FoodItem>()).count == 3)
  }

  @Test("A meal override applies to each copy and separate repeat requests remain intentional")
  func overridesMealsWithoutHiddenDeduplication() throws {
    let container = try container()
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let originalFood = food()
    let first = DiaryEntry(date: sourceDate, mealType: .breakfast, foodItem: originalFood)
    let second = DiaryEntry(
      date: sourceDate, mealType: .dinner, foodItem: originalFood, quantity: 0.25)
    context.insert(first)
    context.insert(second)
    try context.save()
    let firstBatch = try DiaryRepeatLogger.copy(
      entries: [first, second], to: destinationDate, meal: .lunch, in: context)
    let nextBatch = try DiaryRepeatLogger.copy(
      entries: [first, second], to: destinationDate, meal: .snack, in: context)
    #expect(firstBatch.allSatisfy { $0.mealType == .lunch })
    #expect(nextBatch.allSatisfy { $0.mealType == .snack })
    #expect(first.mealType == .breakfast && second.mealType == .dinner)
    #expect(Set((firstBatch + nextBatch).map(\.id)).count == 4)
    #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).count == 6)
    #expect(try context.fetch(FetchDescriptor<FoodItem>()).count == 5)
  }

  private enum SaveFailure: Error, Equatable { case diskFull }

  @Test("Failed persistence removes only the attempted copies, preserving unrelated drafts")
  func saveFailurePreservesPendingEditsInsertsAndDeletions() throws {
    let container = try container()
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let originalFood = food()
    let source = DiaryEntry(
      date: sourceDate, mealType: .dinner, foodItem: originalFood, quantity: 1.5)
    let other = food("Previously saved food")
    let deleted = food("Pending deletion")
    context.insert(source)
    context.insert(other)
    context.insert(deleted)
    try context.save()
    other.name = "Keep this pending edit"
    let draft = food("Keep this new draft")
    context.insert(draft)
    context.delete(deleted)
    var saves = 0

    #expect(throws: SaveFailure.diskFull) {
      try DiaryRepeatLogger.copy(
        entries: [source], to: destinationDate, meal: .breakfast, in: context,
        persist: { attempted in
          saves += 1
          #expect(try attempted.fetch(FetchDescriptor<DiaryEntry>()).count == 2)
          throw SaveFailure.diskFull
        })
    }
    #expect(saves == 1)
    #expect(context.hasChanges)
    #expect(other.name == "Keep this pending edit" && draft.name == "Keep this new draft")
    #expect(source.foodItem?.id == originalFood.id && source.date == sourceDate)
    #expect(source.quantity == 1.5 && source.mealType == .dinner)
    #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).map(\.id) == [source.id])

    // Saving the remaining user's work must not accidentally resurrect the failed copy.
    try context.save()
    let reloaded = ModelContext(container)
    #expect(try reloaded.fetch(FetchDescriptor<DiaryEntry>()).map(\.id) == [source.id])
    let foods = try reloaded.fetch(FetchDescriptor<FoodItem>())
    #expect(Set(foods.map(\.id)) == [originalFood.id, other.id, draft.id])
    #expect(!foods.contains { $0.id == deleted.id })
    #expect(foods.contains { $0.name == "Keep this pending edit" })
  }

  enum InvalidSource: String, CaseIterable {
    case missingFood, emptyName, negativeNutrition, infiniteNutrition, nanNutrition
    case zeroQuantity, negativeQuantity, infiniteQuantity, nanQuantity, scaledOverflow
    case deletedFood, deletedEntry
  }

  @Test("Every invalid source is checked before insertion", arguments: InvalidSource.allCases)
  func rejectsInvalidSourcesWithoutMutation(_ invalid: InvalidSource) throws {
    let container = try container()
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let baseline = food()
    let valid = DiaryEntry(date: sourceDate, mealType: .lunch, foodItem: baseline)
    let invalidEntry = DiaryEntry(date: sourceDate, mealType: .dinner, foodItem: baseline)
    context.insert(valid)
    context.insert(invalidEntry)
    try context.save()
    // Place the invalid entry last to prove validation never inserts a valid prefix first.
    switch invalid {
    case .deletedFood: context.delete(baseline)
    case .deletedEntry: context.delete(invalidEntry)
    case .missingFood: invalidEntry.foodItem = nil
    case .emptyName: baseline.name = " \n\t "
    case .negativeNutrition: baseline.proteinGrams = -0.25
    case .infiniteNutrition: baseline.carbGrams = .infinity
    case .nanNutrition: baseline.fatGrams = .nan
    case .zeroQuantity: invalidEntry.quantity = 0
    case .negativeQuantity: invalidEntry.quantity = -0.5
    case .infiniteQuantity: invalidEntry.quantity = .infinity
    case .nanQuantity: invalidEntry.quantity = .nan
    case .scaledOverflow:
      baseline.calories = Double.greatestFiniteMagnitude
      invalidEntry.quantity = 2
    }
    let foodIDs = try Set(context.fetch(FetchDescriptor<FoodItem>()).map(\.id))
    let diaryIDs = try Set(context.fetch(FetchDescriptor<DiaryEntry>()).map(\.id))
    var saves = 0
    #expect(throws: DiaryRepeatLogger.ValidationError.invalidInput) {
      try DiaryRepeatLogger.preview(entries: [valid, invalidEntry])
    }
    #expect(throws: DiaryRepeatLogger.ValidationError.invalidInput) {
      try DiaryRepeatLogger.copy(
        entries: [valid, invalidEntry], to: destinationDate, in: context,
        persist: { _ in saves += 1 })
    }
    #expect(saves == 0)
    #expect(try Set(context.fetch(FetchDescriptor<FoodItem>()).map(\.id)) == foodIDs)
    #expect(try Set(context.fetch(FetchDescriptor<DiaryEntry>()).map(\.id)) == diaryIDs)
  }

  @Test("Empty input, duplicate source identities and aggregate overflow reject the whole request")
  func rejectsEmptyDuplicatesAndAggregateOverflow() throws {
    let container = try container()
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let firstFood = food()
    let first = DiaryEntry(date: sourceDate, mealType: .lunch, foodItem: firstFood)
    let second = DiaryEntry(date: sourceDate, mealType: .dinner, foodItem: firstFood)
    context.insert(first)
    context.insert(second)
    try context.save()
    for entries in [[], [first, first]] {
      #expect(throws: DiaryRepeatLogger.ValidationError.invalidInput) {
        try DiaryRepeatLogger.preview(entries: entries)
      }
      #expect(throws: DiaryRepeatLogger.ValidationError.invalidInput) {
        try DiaryRepeatLogger.copy(entries: entries, to: destinationDate, in: context)
      }
    }
    second.id = first.id
    #expect(throws: DiaryRepeatLogger.ValidationError.invalidInput) {
      try DiaryRepeatLogger.copy(entries: [first, second], to: destinationDate, in: context)
    }
    second.id = UUID()
    firstFood.fatGrams = Double.greatestFiniteMagnitude
    #expect(first.fat.isFinite && second.fat.isFinite)
    #expect(throws: DiaryRepeatLogger.ValidationError.invalidInput) {
      try DiaryRepeatLogger.preview(entries: [first, second])
    }
    #expect(throws: DiaryRepeatLogger.ValidationError.invalidInput) {
      try DiaryRepeatLogger.copy(entries: [first, second], to: destinationDate, in: context)
    }
    #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).count == 2)
    #expect(try context.fetch(FetchDescriptor<FoodItem>()).count == 1)
  }

  @Test(
    "Non-finite destination dates are rejected without persistence",
    arguments: [Double.infinity, -Double.infinity, Double.nan])
  func rejectsInvalidDestinationDate(_ value: Double) throws {
    let container = try container()
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let source = DiaryEntry(date: sourceDate, mealType: .snack, foodItem: food())
    context.insert(source)
    try context.save()
    #expect(throws: DiaryRepeatLogger.ValidationError.invalidInput) {
      try DiaryRepeatLogger.copy(
        entries: [source], to: Date(timeIntervalSinceReferenceDate: value), in: context,
        persist: { _ in Issue.record("Invalid destination reached persistence") })
    }
    #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).map(\.id) == [source.id])
    #expect(source.date == sourceDate)
  }

  @Test("Source values are frozen before persistence can change another pending edit")
  func freezesSourceValuesBeforeSaving() throws {
    let container = try container()
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let original = food()
    let entry = DiaryEntry(
      date: sourceDate, mealType: .dinner, foodItem: original, quantity: 1.25, note: "Original note"
    )
    context.insert(entry)
    try context.save()
    let copies = try DiaryRepeatLogger.copy(
      entries: [entry], to: destinationDate, in: context,
      persist: { target in
        original.calories = 900
        original.name = "Unrelated source edit"
        entry.quantity = 3
        entry.note = "Changed later"
        try target.save()
      })
    #expect(copies[0].foodItem?.name == "Original food")
    #expect(copies[0].foodItem?.calories == 201.25)
    #expect(copies[0].quantity == 1.25 && copies[0].note == "Original note")
    #expect(copies[0].calories == 251.5625)
  }

  @Test("Menu links from another context resolve the same identity in the destination")
  func resolvesMenuLinkInDestinationContext() throws {
    let container = try container()
    let sourceContext = ModelContext(container)
    sourceContext.autosaveEnabled = false
    let originalMenu = menu()
    let originalFood = food()
    originalFood.menuItem = originalMenu
    let entry = DiaryEntry(date: sourceDate, mealType: .lunch, foodItem: originalFood)
    sourceContext.insert(entry)
    try sourceContext.save()
    let destination = ModelContext(container)
    destination.autosaveEnabled = false
    let result = try DiaryRepeatLogger.copy(entries: [entry], to: destinationDate, in: destination)
    let copiedMenu = try #require(result[0].foodItem?.menuItem)
    #expect(copiedMenu.id == originalMenu.id)
    #expect(copiedMenu.modelContext === destination)
    #expect(copiedMenu !== originalMenu)
    #expect(try destination.fetch(FetchDescriptor<MenuItem>()).count == 1)
    #expect(originalMenu.baseCalories == 250 && originalFood.calories == 201.25)
  }

  @Test("Missing destination menu provenance fails before any rows are inserted")
  func rejectsUnresolvableMenuLink() throws {
    let sourceContainer = try container()
    let sourceContext = ModelContext(sourceContainer)
    sourceContext.autosaveEnabled = false
    let original = food()
    original.menuItem = menu()
    let entry = DiaryEntry(date: sourceDate, mealType: .dinner, foodItem: original)
    sourceContext.insert(entry)
    try sourceContext.save()
    let destinationContainer = try container()
    let destination = ModelContext(destinationContainer)
    destination.autosaveEnabled = false
    #expect(throws: DiaryRepeatLogger.ValidationError.invalidInput) {
      try DiaryRepeatLogger.copy(
        entries: [entry], to: destinationDate, in: destination,
        persist: { _ in Issue.record("Unresolved menu reached persistence") })
    }
    #expect(try destination.fetch(FetchDescriptor<FoodItem>()).isEmpty)
    #expect(try destination.fetch(FetchDescriptor<DiaryEntry>()).isEmpty)
    #expect(try destination.fetch(FetchDescriptor<MenuItem>()).isEmpty)
    #expect(!destination.hasChanges)
    #expect(try sourceContext.fetch(FetchDescriptor<DiaryEntry>()).count == 1)
  }

  @Test("A menu item pending deletion cannot become a new copy's provenance")
  func rejectsDeletedMenuLink() throws {
    let container = try container()
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let originalMenu = menu()
    let originalFood = food()
    originalFood.menuItem = originalMenu
    let entry = DiaryEntry(date: sourceDate, mealType: .lunch, foodItem: originalFood)
    context.insert(entry)
    try context.save()
    context.delete(originalMenu)
    #expect(throws: DiaryRepeatLogger.ValidationError.invalidInput) {
      try DiaryRepeatLogger.copy(entries: [entry], to: destinationDate, in: context)
    }
    #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).map(\.id) == [entry.id])
    #expect(try context.fetch(FetchDescriptor<FoodItem>()).count == 1)
    #expect(originalMenu.isDeleted)
  }

  @Test(
    "Calendar-selected previous days stay correct across 23-hour and 25-hour days",
    arguments: [3, 11])
  func usesExactCalendarSelectedDateAcrossDST(_ month: Int) throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
    let dayAfterChange = month == 3 ? 11 : 4
    let selectedDay = try #require(
      calendar.date(from: DateComponents(year: 2024, month: month, day: dayAfterChange)))
    let previousDay = try #require(calendar.date(byAdding: .day, value: -1, to: selectedDay))
    let interval = try #require(calendar.dateInterval(of: .day, for: previousDay))
    let expectedHours = month == 3 ? 23.0 : 25.0
    #expect(interval.duration == expectedHours * 3_600)
    #expect(selectedDay.timeIntervalSince(previousDay) == expectedHours * 3_600)
    let destination = try #require(
      calendar.date(byAdding: .minute, value: 8 * 60 + 15, to: selectedDay))
    let container = try container()
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let source = DiaryEntry(
      date: interval.end.addingTimeInterval(-0.125), mealType: .snack, foodItem: food(),
      quantity: 0.25)
    let outside = DiaryEntry(
      date: interval.start.addingTimeInterval(-0.125), mealType: .dinner, foodItem: food())
    context.insert(source)
    context.insert(outside)
    try context.save()
    let candidates = try context.fetch(FetchDescriptor<DiaryEntry>())
    let previousEntries = candidates.filter { $0.date >= interval.start && $0.date < interval.end }
    #expect(previousEntries.map(\.id) == [source.id])
    let copied = try DiaryRepeatLogger.copy(entries: previousEntries, to: destination, in: context)
    #expect(copied.count == 1 && copied[0].date == destination)
    #expect(copied[0].mealType == .snack && copied[0].quantity == 0.25)
    #expect(source.date == interval.end.addingTimeInterval(-0.125))
  }
}
