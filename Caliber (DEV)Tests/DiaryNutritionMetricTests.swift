import Foundation
import Testing

@testable import Caliber__DEV_

@MainActor
@Suite("Diary nutrition presentation")
struct DiaryNutritionMetricTests {
  @Test func reportedEnergyRemainsIndependentFromMacroEnergy() {
    let food = FoodItem(
      name: "Fictional bowl", calories: 640, proteinGrams: 48,
      carbGrams: 70, fatGrams: 18, servingDescription: "1 stated serving")
    let entry = DiaryEntry(date: .now, mealType: .lunch, foodItem: food)
    let totals = MacroCalculator.totals(for: [entry])
    let energy = DiaryNutritionMetric(value: totals.calories, goal: 2300)
    #expect(energy.value == 640)
    #expect(totals.protein * 4 + totals.carbs * 4 + totals.fat * 9 == 634)
    #expect(energy.remaining == 1660)
    #expect(food.calories == 640 && entry.quantity == 1)
  }

  @Test func belowAtAndAboveTargetKeepActualValues() {
    let under = DiaryNutritionMetric(value: 1840, goal: 2300)
    #expect(under.progress == 0.8 && under.remaining == 460 && under.aboveGoal == 0)
    let equal = DiaryNutritionMetric(value: 2300, goal: 2300)
    #expect(equal.progress == 1 && equal.remaining == 0 && equal.aboveGoal == 0)
    let over = DiaryNutritionMetric(value: 2600.25, goal: 2300)
    #expect(over.value == 2600.25 && over.goal == 2300)
    #expect(over.progress == 1 && over.remaining == 0 && over.aboveGoal == 300.25)
  }

  @Test func missingOrInvalidGoalsNeverBecomeTargets() {
    for goal in [nil, 0, -1, Double.nan, .infinity, -.infinity] as [Double?] {
      let metric = DiaryNutritionMetric(value: 100.25, goal: goal)
      #expect(metric.value == 100.25 && metric.goal == nil)
      #expect(metric.progress == nil && metric.remaining == nil && metric.aboveGoal == nil)
    }
  }

  @Test func invalidRecordedValueDoesNotLookLikeZeroIntake() {
    for value in [-1, Double.nan, .infinity, -.infinity] {
      let metric = DiaryNutritionMetric(value: value, goal: 2300)
      #expect(metric.value == nil && metric.progress == nil)
      #expect(metric.remaining == nil && metric.aboveGoal == nil)
    }
    let emptyTotal = DiaryNutritionMetric(value: 0, goal: 2300)
    #expect(emptyTotal.value == 0 && emptyTotal.progress == 0 && emptyTotal.remaining == 2300)
  }

  @Test func extremePositiveValuesCannotOverflowTheRing() {
    let metric = DiaryNutritionMetric(value: .greatestFiniteMagnitude, goal: .leastNonzeroMagnitude)
    #expect(metric.progress == 1 && metric.aboveGoal?.isFinite == true)
    let small = DiaryNutritionMetric(value: .leastNonzeroMagnitude, goal: .greatestFiniteMagnitude)
    #expect(small.progress?.isFinite == true && small.remaining?.isFinite == true)
  }
}
