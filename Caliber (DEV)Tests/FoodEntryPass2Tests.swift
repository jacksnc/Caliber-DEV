import Foundation
import SwiftData
import Testing

@testable import Caliber__DEV_

@MainActor @Test
func manualDraftRequiresAllFourMacrosAndNeverInventsZeroValues() throws {
  let container = try ModelContainer(
    for: FoodItem.self, DiaryEntry.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
  )
  let context = ModelContext(container)
  context.autosaveEnabled = false

  let calorieOnly = FoodEntryPass2ManualDraft(
    name: "Broth",
    servingDescription: "1 mug",
    quantity: "1",
    calories: "45",
    protein: "",
    carbs: "",
    fat: ""
  )
  #expect(calorieOnly.perServingTotals() == nil)
  #expect(calorieOnly.scaledTotals() == nil)
  #expect(!calorieOnly.canSave())
  #expect(throws: FoodEntryPass2ManualDraft.ValidationError.invalidInput) {
    try FoodEntryPass2ManualLogger.log(
      draft: calorieOnly,
      mealType: .dinner,
      date: Date(timeIntervalSince1970: 1_700_000_000),
      in: context
    )
  }

  let partialScan = FoodEntryPass2ManualDraft(
    prefill: FoodEntryPrefill(
      name: "Scanned Bar",
      servingDescription: "1 bar",
      calories: "210",
      protein: "15",
      carbs: "",
      fat: "7"
    )
  )
  #expect(!partialScan.canSave())
  #expect(try context.fetch(FetchDescriptor<FoodItem>()).isEmpty)
  #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).isEmpty)

  var explicitZeroMacro = partialScan
  explicitZeroMacro.carbs = "0"
  #expect(explicitZeroMacro.canSave())
  #expect(
    explicitZeroMacro.perServingTotals()
      == MacroTotals(calories: 210, protein: 15, carbs: 0, fat: 7)
  )
}

@MainActor @Test
func manualDraftScalesPortionsSupportsCommaDecimalsAndRejectsInvalidValues() {
  let french = Locale(identifier: "fr_FR")
  let draft = FoodEntryPass2ManualDraft(
    name: "  Skyr Nature  ",
    servingDescription: "   ",
    quantity: "1,5",
    calories: "120,5",
    protein: "16,2",
    carbs: "6,4",
    fat: "0,2",
    saveToLibrary: false
  )
  #expect(draft.trimmedName == "Skyr Nature")
  #expect(draft.resolvedServingDescription == "1 serving")
  #expect(draft.canSave(locale: french))

  let scaled = draft.scaledTotals(locale: french)
  #expect(scaled != nil)
  #expect(abs((scaled?.calories ?? 0) - 180.75) < 0.0001)
  #expect(abs((scaled?.protein ?? 0) - 24.3) < 0.0001)
  #expect(abs((scaled?.carbs ?? 0) - 9.6) < 0.0001)
  #expect(abs((scaled?.fat ?? 0) - 0.3) < 0.0001)

  for badQuantity in ["", "0", "-0.5", "nan", "inf"] {
    var invalid = draft
    invalid.quantity = badQuantity
    #expect(!invalid.canSave(locale: french))
  }

  var negativeMacro = draft
  negativeMacro.fat = "-1"
  #expect(!negativeMacro.canSave(locale: french))

  var blankName = draft
  blankName.name = "   "
  #expect(!blankName.canSave(locale: french))
}

@MainActor @Test
func manualLoggerPreservesBackdatedMealLibraryFlagAndCleansUpFailedSaves() throws {
  enum SimulatedSaveError: Error { case diskFull }

  let container = try ModelContainer(
    for: FoodItem.self, DiaryEntry.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
  )
  let context = ModelContext(container)
  context.autosaveEnabled = false

  let backdated = Date(timeIntervalSince1970: 1_700_000_000)
  let oneOffDraft = FoodEntryPass2ManualDraft(
    name: "Campfire Chili",
    servingDescription: "1 ladle",
    quantity: "2",
    calories: "240",
    protein: "22",
    carbs: "18",
    fat: "8",
    saveToLibrary: false
  )
  let oneOffEntry = try FoodEntryPass2ManualLogger.log(
    draft: oneOffDraft,
    mealType: .dinner,
    date: backdated,
    locale: Locale(identifier: "en_US_POSIX"),
    in: context
  )
  #expect(oneOffEntry.date == backdated)
  #expect(oneOffEntry.mealType == .dinner)
  #expect(oneOffEntry.quantity == 2)
  #expect(oneOffEntry.calories == 480)
  #expect(oneOffEntry.protein == 44)
  #expect(oneOffEntry.foodItem?.isSavedToLibrary == false)
  #expect(oneOffEntry.foodItem?.servingDescription == "1 ladle")

  var savedDraft = oneOffDraft
  savedDraft.name = "Saved Oatmeal"
  savedDraft.servingDescription = ""
  savedDraft.quantity = "0.5"
  savedDraft.saveToLibrary = true
  let savedEntry = try FoodEntryPass2ManualLogger.log(
    draft: savedDraft,
    mealType: .breakfast,
    date: backdated,
    locale: Locale(identifier: "en_US_POSIX"),
    in: context
  )
  #expect(savedEntry.foodItem?.isSavedToLibrary == true)
  #expect(savedEntry.foodItem?.servingDescription == "1 serving")
  #expect(savedEntry.calories == 120)

  let unrelated = FoodItem(
    name: "Pending Draft",
    calories: 50,
    proteinGrams: 5,
    carbGrams: 5,
    fatGrams: 1,
    servingDescription: "1 piece"
  )
  context.insert(unrelated)

  #expect(throws: SimulatedSaveError.self) {
    try FoodEntryPass2ManualLogger.log(
      draft: savedDraft,
      mealType: .snack,
      date: backdated,
      locale: Locale(identifier: "en_US_POSIX"),
      in: context,
      persist: { _ in throw SimulatedSaveError.diskFull }
    )
  }
  #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).count == 2)
  #expect(try context.fetch(FetchDescriptor<FoodItem>()).contains { $0.id == unrelated.id })
}

@Test
func contextFormatterDistinguishesTodayYesterdayAndBackdatedSummaries() {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0)!
  let locale = Locale(identifier: "en_US_POSIX")
  let reference = Date(timeIntervalSince1970: 1_710_504_000)  // 2024-03-15 12:00:00 UTC
  let yesterday = calendar.date(byAdding: .day, value: -1, to: reference)!
  let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: reference)!
  let tomorrow = calendar.date(byAdding: .day, value: 1, to: reference)!

  #expect(
    FoodEntryPass2ContextFormatter.summary(
      meal: .breakfast,
      date: reference,
      referenceDate: reference,
      calendar: calendar,
      locale: locale
    ) == "Breakfast · Today"
  )
  #expect(
    FoodEntryPass2ContextFormatter.summary(
      meal: .dinner,
      date: yesterday,
      referenceDate: reference,
      calendar: calendar,
      locale: locale
    ) == "Dinner · Yesterday"
  )
  #expect(
    !FoodEntryPass2ContextFormatter.isBackdated(
      reference, referenceDate: reference, calendar: calendar))
  #expect(
    !FoodEntryPass2ContextFormatter.isBackdated(
      tomorrow, referenceDate: reference, calendar: calendar))
  #expect(
    FoodEntryPass2ContextFormatter.isBackdated(
      yesterday, referenceDate: reference, calendar: calendar))
  #expect(
    FoodEntryPass2ContextFormatter.isBackdated(
      threeDaysAgo, referenceDate: reference, calendar: calendar))
}
