import Foundation
import SwiftData
import Testing

@testable import Caliber__DEV_

@MainActor
@Suite("Stack bookkeeping")
struct StackPlannerTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }
  /// Monday 2026-10-26 09:12 UTC.
  private let now = Date(timeIntervalSince1970: 1_793_005_920)

  private func context() throws -> ModelContext {
    let container = try ModelContainer(
      for: StackStore.schema,
      configurations: ModelConfiguration(schema: StackStore.schema, isStoredInMemoryOnly: true))
    return container.mainContext
  }

  private func at(_ hour: Int, _ minute: Int = 0, daysAgo: Int = 0) -> Date {
    let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
    return calendar.date(byAdding: .minute, value: hour * 60 + minute, to: day)!
  }

  private func compound(
    _ name: String = "Compound A", repeatPattern: StackRepeat = .daily, time: Int = 8 * 60
  ) -> StackCompound {
    StackCompound(
      name: name, form: .pen, unit: .mg, amountText: "0.5", repeatPattern: repeatPattern,
      timeMinutes: time, startDate: at(0, daysAgo: 30))
  }

  @Test func overdueDoseIsDueAndLoggingMarksItTaken() throws {
    let context = try context()
    let daily = compound()
    context.insert(daily)
    var today = StackPlanner.today(for: [daily], now: now, calendar: calendar)
    #expect(today.count == 1)
    #expect(today[0].scheduledAt == at(8))
    #expect(today[0].isOpen)

    context.insert(
      StackDose(compound: daily, amountText: "0.5", takenAt: at(8, 10), scheduledFor: at(8)))
    try context.save()
    today = StackPlanner.today(for: [daily], now: now, calendar: calendar)
    #expect(today[0].isTaken)
  }

  @Test func skippedDoseIsNeitherTakenNorOpen() throws {
    let context = try context()
    let daily = compound()
    context.insert(daily)
    context.insert(StackDose(compound: daily, amountText: "0.5", takenAt: nil, scheduledFor: at(8)))
    try context.save()
    let item = try #require(StackPlanner.today(for: [daily], now: now, calendar: calendar).first)
    #expect(!item.isTaken)
    #expect(!item.isOpen)
  }

  @Test func pausedAndAsNeededCompoundsHaveNoSchedule() throws {
    let context = try context()
    let paused = compound("Paused")
    paused.isPaused = true
    let asNeeded = compound("As needed", repeatPattern: .asNeeded)
    [paused, asNeeded].forEach(context.insert)
    #expect(StackPlanner.today(for: [paused, asNeeded], now: now, calendar: calendar).isEmpty)
  }

  @Test func weekdayScheduleOnlyMatchesChosenDays() throws {
    let context = try context()
    let weekly = compound(repeatPattern: .weekdays)
    weekly.weekdays = [3]  // Wednesday
    context.insert(weekly)
    #expect(StackPlanner.today(for: [weekly], now: now, calendar: calendar).isEmpty)
    let next = try #require(StackPlanner.next(for: [weekly], now: now, calendar: calendar))
    #expect(next.scheduledAt == calendar.date(byAdding: .day, value: 2, to: at(8)))
  }

  @Test func supplyCountsDownFromItsStartDate() throws {
    let context = try context()
    let pen = compound()
    pen.supplyDoses = 4
    pen.supplyStartedAt = at(0, daysAgo: 8)
    context.insert(pen)
    context.insert(
      StackDose(compound: pen, amountText: "0.5", takenAt: at(8, daysAgo: 14), scheduledFor: nil))
    context.insert(
      StackDose(compound: pen, amountText: "0.5", takenAt: at(8, daysAgo: 7), scheduledFor: nil))
    context.insert(StackDose(compound: pen, amountText: "0.5", takenAt: nil, scheduledFor: at(8)))
    try context.save()
    #expect(StackPlanner.remainingSupply(of: pen) == 3)
    pen.supplyDoses = 0
    #expect(StackPlanner.remainingSupply(of: pen) == nil)
  }

  @Test func secondDoseSoonAfterTheLastIsFlagged() throws {
    let context = try context()
    let daily = compound()
    context.insert(daily)
    context.insert(
      StackDose(compound: daily, amountText: "0.5", takenAt: at(8), scheduledFor: at(8)))
    try context.save()
    #expect(StackPlanner.doubleDoseWarning(for: daily, at: at(9)) != nil)
    #expect(StackPlanner.doubleDoseWarning(for: daily, at: at(8, daysAgo: -1)) == nil)
  }

  @Test func estimateNeedsHalfLifeAndSource() throws {
    let context = try context()
    let pen = compound()
    context.insert(pen)
    context.insert(
      StackDose(compound: pen, amountText: "1", takenAt: at(0, daysAgo: 2), scheduledFor: nil))
    try context.save()
    let range = at(0, daysAgo: 2)...at(0)
    #expect(StackPlanner.levelSeries(for: pen, in: range) == nil)
    pen.halfLifeHours = 24
    #expect(StackPlanner.levelSeries(for: pen, in: range) == nil)
    pen.halfLifeSource = "My label"
    let series = try #require(StackPlanner.levelSeries(for: pen, in: range, points: 3))
    // Instant-absorption model from HOW_WE_CALCULATE: D × 0.5^(elapsed / half-life).
    #expect(abs(series[0].amount - 1) < 1e-9)
    #expect(abs(series[1].amount - 0.5) < 1e-9)
    #expect(abs(series[2].amount - 0.25) < 1e-9)
  }

  @Test func decimalsRoundTripInTheUsersLocale() {
    let german = Locale(identifier: "de_DE")
    #expect(StackDecimal.canonical("0,25", locale: german) == "0.25")
    #expect(StackDecimal.display("0.25", locale: german) == "0,25")
    #expect(StackDecimal.canonical("0", locale: german) == nil)
    #expect(StackDecimal.canonical("abc", locale: german) == nil)
  }
}
