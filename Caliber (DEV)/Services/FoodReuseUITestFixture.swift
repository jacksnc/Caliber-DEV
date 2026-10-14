#if DEBUG
  import Foundation
  import SwiftData

  /// Explicit debug launch fixture, used only with an isolated in-memory test store.
  @MainActor enum FoodReuseUITestFixture {
    static func seed(in context: ModelContext, calendar: Calendar) throws {
      guard try context.fetchCount(FetchDescriptor<DiaryEntry>()) == 0,
        let yesterday = DiaryDay.previous(before: .now, calendar: calendar)
      else { return }
      func breakfast() -> FoodItem {
        FoodItem(
          name: "Fictional breakfast", calories: 200.5, proteinGrams: 10.25,
          carbGrams: 20.5, fatGrams: 5.125, servingDescription: "1 fictional plate")
      }
      let first = breakfast()
      let snack = FoodItem(
        name: "Fictional snack", calories: 100, proteinGrams: 5,
        carbGrams: 10, fatGrams: 2, servingDescription: "1 fictional pack")
      let today = breakfast()
      for food in [first, snack, today] { context.insert(food) }
      context.insert(
        DiaryEntry(
          date: yesterday, mealType: .breakfast, foodItem: first, quantity: 1.5,
          note: "Fictional note"))
      context.insert(DiaryEntry(date: yesterday, mealType: .snack, foodItem: snack, quantity: 2))
      context.insert(DiaryEntry(date: .now, mealType: .lunch, foodItem: today, quantity: 0.5))
      try context.save()
    }
  }
#endif
