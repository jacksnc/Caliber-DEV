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
  let tenDaysAhead = calendar.date(byAdding: .day, value: 10, to: reference)!

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
    FoodEntryPass2ContextFormatter.summary(
      meal: .lunch,
      date: tomorrow,
      referenceDate: reference,
      calendar: calendar,
      locale: locale
    ) == "Lunch · Tomorrow"
  )
  #expect(
    FoodEntryPass2ContextFormatter.summary(
      meal: .snack,
      date: tenDaysAhead,
      referenceDate: reference,
      calendar: calendar,
      locale: locale
    ) == "Snack · Mar 25, 2024"
  )

  #expect(
    FoodEntryPass2ContextFormatter.dateRelation(
      for: reference, referenceDate: reference, calendar: calendar) == .today
  )
  #expect(
    FoodEntryPass2ContextFormatter.badgeTitle(
      for: reference, referenceDate: reference, calendar: calendar) == nil
  )
  #expect(
    FoodEntryPass2ContextFormatter.dateRelation(
      for: yesterday, referenceDate: reference, calendar: calendar) == .past
  )
  #expect(
    FoodEntryPass2ContextFormatter.badgeTitle(
      for: yesterday, referenceDate: reference, calendar: calendar) == "Past date"
  )
  #expect(
    FoodEntryPass2ContextFormatter.dateRelation(
      for: tomorrow, referenceDate: reference, calendar: calendar) == .future
  )
  #expect(
    FoodEntryPass2ContextFormatter.badgeTitle(
      for: tomorrow, referenceDate: reference, calendar: calendar) == "Future date"
  )
  #expect(
    FoodEntryPass2ContextFormatter.badgeTitle(
      for: tenDaysAhead, referenceDate: reference, calendar: calendar) == "Future date"
  )
  #expect(
    !FoodEntryPass2ContextFormatter.isBackdated(
      reference, referenceDate: reference, calendar: calendar))
  #expect(
    !FoodEntryPass2ContextFormatter.isBackdated(
      tomorrow, referenceDate: reference, calendar: calendar))
  #expect(
    !FoodEntryPass2ContextFormatter.isBackdated(
      tenDaysAhead, referenceDate: reference, calendar: calendar))
  #expect(
    FoodEntryPass2ContextFormatter.isFutureDated(
      tomorrow, referenceDate: reference, calendar: calendar))
  #expect(
    FoodEntryPass2ContextFormatter.isFutureDated(
      tenDaysAhead, referenceDate: reference, calendar: calendar))
  #expect(
    FoodEntryPass2ContextFormatter.isBackdated(
      yesterday, referenceDate: reference, calendar: calendar))
  #expect(
    FoodEntryPass2ContextFormatter.isBackdated(
      threeDaysAgo, referenceDate: reference, calendar: calendar))
}

@Test @MainActor
func futureDateClassificationUsesAppCalendarAndRetainsExactMealAndDate() throws {
  let locale = Locale(identifier: "en_US_POSIX")
  var utcCalendar = Calendar(identifier: .gregorian)
  utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
  var westernCalendar = Calendar(identifier: .gregorian)
  westernCalendar.timeZone = TimeZone(secondsFromGMT: -5 * 3600)!

  // 2024-03-15 23:00:00 UTC == 2024-03-15 18:00:00 UTC-5
  let reference = Date(timeIntervalSince1970: 1_710_543_600)
  // 2024-03-16 02:00:00 UTC == 2024-03-15 21:00:00 UTC-5
  let instant = Date(timeIntervalSince1970: 1_710_554_400)
  // 2024-03-20 02:00:00 UTC == 2024-03-19 21:00:00 UTC-5
  let multiDayFuture = Date(timeIntervalSince1970: 1_710_900_000)

  #expect(
    FoodEntryPass2ContextFormatter.dateRelation(
      for: instant, referenceDate: reference, calendar: utcCalendar) == .future
  )
  #expect(
    FoodEntryPass2ContextFormatter.badgeTitle(
      for: instant, referenceDate: reference, calendar: utcCalendar) == "Future date"
  )
  #expect(
    FoodEntryPass2ContextFormatter.dateRelation(
      for: instant, referenceDate: reference, calendar: westernCalendar) == .today
  )
  #expect(
    FoodEntryPass2ContextFormatter.badgeTitle(
      for: instant, referenceDate: reference, calendar: westernCalendar) == nil
  )
  #expect(
    FoodEntryPass2ContextFormatter.summary(
      meal: .breakfast,
      date: multiDayFuture,
      referenceDate: reference,
      calendar: utcCalendar,
      locale: locale
    ) == "Breakfast · Mar 20, 2024"
  )
  #expect(
    FoodEntryPass2ContextFormatter.summary(
      meal: .breakfast,
      date: multiDayFuture,
      referenceDate: reference,
      calendar: westernCalendar,
      locale: locale
    ) == "Breakfast · Mar 19, 2024"
  )

  let container = try ModelContainer(
    for: FoodItem.self, DiaryEntry.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
  )
  let context = ModelContext(container)
  context.autosaveEnabled = false
  let draft = FoodEntryPass2ManualDraft(
    name: "Planned Oats",
    servingDescription: "1 bowl",
    quantity: "1.5",
    calories: "200",
    protein: "10",
    carbs: "32",
    fat: "4",
    saveToLibrary: false
  )
  let logged = try FoodEntryPass2ManualLogger.log(
    draft: draft,
    mealType: .breakfast,
    date: multiDayFuture,
    locale: locale,
    in: context
  )
  #expect(logged.mealType == .breakfast)
  #expect(logged.date == multiDayFuture)
  #expect(logged.calories == 300)
}
