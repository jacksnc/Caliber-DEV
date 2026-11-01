import CaliberCore
import Foundation
import SwiftData
import Testing

@testable import Caliber__DEV_

/// Read-only energy text for Diary, food search and copy previews. Stored values stay kcal.
@MainActor
@Suite("Energy display in the saved unit")
struct CaliberEnergyDisplayTests {
  private let english = Locale(identifier: "en_US")
  private let german = Locale(identifier: "de_DE")

  private func container() throws -> ModelContainer {
    let schema = Schema([
      FoodItem.self, DiaryEntry.self, Restaurant.self, MenuItem.self, MenuItemModifier.self,
      BuildableItemTemplate.self, BuildComponentCategory.self, BuildComponentOption.self,
      SavedMeal.self, SavedMealItem.self,
    ])
    return try ModelContainer(
      for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
  }

  private func food(_ calories: Double) -> FoodItem {
    FoodItem(
      name: "Fictional energy check", calories: calories, proteinGrams: 10.5, carbGrams: 20.25,
      fatGrams: 3.125, servingDescription: "1 fictional serving")
  }

  @Test("kcal keeps the exact recorded figure and the wording existing screens use")
  func kilocaloriesKeepExactFractionalText() {
    let energy = CaliberEnergyDisplay(unit: .kilocalories, locale: english)
    #expect(energy.number(100.25) == "100.25")
    #expect(energy.number(150.375) == "150.375")
    #expect(energy.number(1462) == "1462")
    #expect(energy.number(0) == "0")
    #expect(energy.symbol == "kcal")
    #expect(energy.short(100.25) == "100.25 kcal")
    #expect(energy.sentence(100.25) == "100.25 calories")
    #expect(energy.spoken(1462) == "1462 calories")
    #expect(CaliberEnergyDisplay(unit: .kilocalories, locale: german).number(100.25) == "100,25")
  }

  @Test("kJ converts once with UnitFormatting and is labelled kJ")
  func kilojoulesConvertOnceAndLabel() {
    let energy = CaliberEnergyDisplay(unit: .kilojoules, locale: english)
    // 100.25 × 4.184 = 419.446; 1462 × 4.184 = 6117.008; 2350 × 4.184 = 9832.4.
    #expect(energy.number(100.25) == "419.4")
    #expect(energy.number(1462) == "6,117")
    #expect(energy.number(2350) == "9,832.4")
    #expect(energy.number(0) == "0")
    #expect(energy.symbol == "kJ")
    #expect(energy.short(100.25) == "419.4 kJ")
    #expect(energy.sentence(1462) == "6,117 kJ")
    #expect(energy.spoken(1462) == "6,117 kilojoules")
    let direct = UnitFormatting.number(
      UnitFormatting.energy(1462, unit: .kilojoules), locale: english, fractionDigits: 1)
    #expect(energy.number(1462) == direct)
    let germanKJ = CaliberEnergyDisplay(unit: .kilojoules, locale: german)
    #expect(germanKJ.number(100.25) == "419,4")
    #expect(germanKJ.number(1462) == "6.117")
  }

  @Test("Totals are summed in kcal first, then shown once")
  func totalsUseCanonicalSumNotRoundedRows() {
    let energy = CaliberEnergyDisplay(unit: .kilojoules, locale: english)
    let rows = [0.04, 0.04, 0.04]
    // Each row shows 0.2 kJ (0.16736). Adding those would claim 0.6 kJ; the real total of
    // 0.12 kcal is 0.50208 kJ.
    #expect(rows.map { energy.number($0) } == ["0.2", "0.2", "0.2"])
    #expect(energy.number(rows.reduce(0, +)) == "0.5")
  }

  @Test("Diary balance arithmetic stays in kcal; only the result is converted")
  func diaryBalanceConvertsResultOnly() {
    let metric = DiaryNutritionMetric(value: 1462, goal: 2350)
    #expect(metric.remaining == 888)
    #expect(CaliberEnergyDisplay(unit: .kilojoules, locale: english).number(888) == "3,715.4")
    #expect(CaliberEnergyDisplay(unit: .kilocalories, locale: english).number(888) == "888")
    let over = DiaryNutritionMetric(value: 2350.25, goal: 2350)
    #expect(over.aboveGoal == 0.25)
    #expect(CaliberEnergyDisplay(unit: .kilocalories, locale: english).number(0.25) == "0.25")
    #expect(CaliberEnergyDisplay(unit: .kilojoules, locale: english).number(0.25) == "1")
  }

  @Test("Search rows, copy previews and totals leave stored kcal unchanged")
  func displayNeverChangesStoredValues() throws {
    let container = try container()
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let saved = food(200.5)
    context.insert(saved)
    let half = DiaryEntry(date: .now, mealType: .lunch, foodItem: saved, quantity: 0.5)
    let whole = DiaryEntry(date: .now, mealType: .dinner, foodItem: saved, quantity: 1.25)
    context.insert(half)
    context.insert(whole)

    let preview = try DiaryRepeatLogger.preview(entries: [half, whole])
    #expect(preview.calories == 350.875)
    let kcal = CaliberEnergyDisplay(unit: .kilocalories, locale: english)
    let kJ = CaliberEnergyDisplay(unit: .kilojoules, locale: english)
    // Copy total and per-row previews (CopyDiaryView); food rows (FoodSearchView).
    #expect("1 food · \(kcal.sentence(half.calories))" == "1 food · 100.25 calories")
    #expect(kcal.sentence(preview.calories) == "350.875 calories")
    #expect(kJ.sentence(preview.calories) == "1,468.1 kJ")
    #expect(kcal.short(saved.calories * 0.5) == "100.25 kcal")
    #expect(kJ.short(saved.calories * 0.5) == "419.4 kJ")
    // Meal heading in Diary.
    let lunch = MacroCalculator.totals(for: [half])
    #expect(kJ.sentence(lunch.calories) == "419.4 kJ")

    // Nothing above wrote back: food, entries, portions and totals keep canonical kcal.
    #expect(saved.calories == 200.5)
    #expect(half.quantity == 0.5 && whole.quantity == 1.25)
    #expect(half.calories == 100.25 && whole.calories == 250.625)
    #expect(MacroCalculator.totals(for: [half, whole]).calories == 350.875)
    #expect(try DiaryRepeatLogger.preview(entries: [half, whole]) == preview)
  }
}
