#if DEBUG
  import Foundation
  import HeliosTime
  import SwiftData

  /// Fictional entries for isolated UI tests and screenshots. The names are invented and
  /// the half-life is a test number marked as such, not a reference value.
  enum StackFixture {
    @MainActor static func seed(in context: ModelContext, now: Date, calendar: Calendar) {
      let today = calendar.startOfDay(for: now)
      let start = calendar.date(byAdding: .day, value: -27, to: today) ?? today
      let weekday = StackPlanner.localDate(now, calendar: calendar).isoWeekday

      let weekly = StackCompound(
        name: "Compound A", form: .pen, unit: .mg, amountText: "0.5", repeatPattern: .weekdays,
        weekdays: [weekday], timeMinutes: 8 * 60, startDate: start, halfLifeHours: 160,
        halfLifeSource: "Fictional test value", supplyDoses: 4,
        supplyStartedAt: calendar.date(byAdding: .day, value: -8, to: today))
      let daily = StackCompound(
        name: "Compound B", form: .vial, unit: .mcg, amountText: "250", repeatPattern: .daily,
        timeMinutes: 20 * 60 + 30, startDate: start)
      let supplement = StackCompound(
        name: "Vitamin D", form: .capsule, unit: .capsules, amountText: "1",
        repeatPattern: .daily, timeMinutes: 7 * 60 + 30, startDate: start)
      [weekly, daily, supplement].forEach(context.insert)

      for week in 1...3 {
        guard let day = calendar.date(byAdding: .day, value: -7 * week, to: today),
          let time = calendar.date(byAdding: .minute, value: 8 * 60 + 5, to: day)
        else { continue }
        let scheduled = calendar.date(byAdding: .minute, value: 8 * 60, to: day)
        context.insert(
          StackDose(
            compound: weekly, amountText: "0.5", takenAt: time, scheduledFor: scheduled,
            site: "Abdomen, left"))
      }
      if let taken = calendar.date(byAdding: .minute, value: 7 * 60 + 40, to: today) {
        context.insert(
          StackDose(
            compound: supplement, amountText: "1", takenAt: min(taken, now),
            scheduledFor: calendar.date(byAdding: .minute, value: 7 * 60 + 30, to: today)))
      }
      try? context.save()
    }
  }
#endif
