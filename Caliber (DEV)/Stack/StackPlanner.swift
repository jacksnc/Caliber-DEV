import Foundation
import HeliosTime
import StackCore

/// One scheduled dose and what happened to it.
struct StackScheduledDose: Identifiable, Equatable {
  let compoundName: String
  let scheduledAt: Date
  let status: DoseStatus
  let dose: StackDose?

  var id: String { compoundName + "@" + String(scheduledAt.timeIntervalSince1970) }

  var isTaken: Bool { [.takenOnTime, .takenLate, .takenEarly].contains(status) }
  var isOpen: Bool { status == .due || status == .upcoming }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id && lhs.status == rhs.status && lhs.dose?.takenAt == rhs.dose?.takenAt
  }
}

/// Pure bookkeeping over the person's own entries: when doses are due, what was logged,
/// how much supply is left and the illustrative active amount. It never proposes an amount
/// or a time (HOW_WE_CALCULATE, "Stack arithmetic").
enum StackPlanner {
  /// The StackCore schedule for a compound, or nil when it is paused.
  static func schedule(for compound: StackCompound, calendar: Calendar) -> Schedule? {
    guard !compound.isPaused else { return nil }
    let start = localDate(compound.startDate, calendar: calendar)
    let recurrence: Recurrence
    switch compound.repeatPattern {
    case .daily: recurrence = .daily
    case .everyNDays: recurrence = .everyNDays(max(1, compound.intervalDays))
    case .weekly: recurrence = .everyNWeeks(1)
    case .weekdays:
      let days = Set(compound.weekdays.filter { (1...7).contains($0) })
      recurrence = days.isEmpty ? .everyNWeeks(1) : .weekdays(days)
    case .asNeeded: recurrence = .prn
    }
    return Schedule(
      startDate: start, recurrence: recurrence, timesOfDay: [compound.timeMinutes])
  }

  /// Every scheduled dose in `range`, matched to the entry logged for it.
  static func scheduledDoses(
    for compounds: [StackCompound], in range: Range<Date>, now: Date, calendar: Calendar
  ) -> [StackScheduledDose] {
    compounds.flatMap { compound -> [StackScheduledDose] in
      guard let schedule = schedule(for: compound, calendar: calendar) else { return [] }
      return ScheduleEngine.occurrences(of: schedule, in: range, userCalendar: calendar).map {
        occurrence in
        let dose = compound.doses.first { $0.scheduledFor == occurrence.scheduledAt }
        let log: DoseLogEntry? = dose.map { $0.takenAt.map(DoseLogEntry.taken(at:)) ?? .skipped }
        return StackScheduledDose(
          compoundName: compound.name, scheduledAt: occurrence.scheduledAt,
          status: DoseStateMachine.status(
            scheduledAt: occurrence.scheduledAt, log: log, now: now),
          dose: dose)
      }
    }
    .sorted { $0.scheduledAt < $1.scheduledAt }
  }

  /// Today's doses, from local midnight to the next.
  static func today(
    for compounds: [StackCompound], now: Date, calendar: Calendar
  ) -> [StackScheduledDose] {
    let start = calendar.startOfDay(for: now)
    let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
    return scheduledDoses(for: compounds, in: start..<end, now: now, calendar: calendar)
  }

  /// The next dose that is due or upcoming, looking up to two weeks ahead.
  static func next(
    for compounds: [StackCompound], now: Date, calendar: Calendar
  ) -> StackScheduledDose? {
    let start = calendar.startOfDay(for: now)
    let end = calendar.date(byAdding: .day, value: 15, to: start) ?? now
    return scheduledDoses(for: compounds, in: start..<end, now: now, calendar: calendar)
      .first { $0.status == .due || $0.status == .upcoming }
  }

  /// Doses left in the current supply, or nil when supply is not tracked.
  static func remainingSupply(of compound: StackCompound) -> Int? {
    guard compound.supplyDoses > 0 else { return nil }
    let since = compound.supplyStartedAt ?? .distantPast
    let used = compound.doses.filter { ($0.takenAt ?? .distantPast) >= since }.count
    return max(0, compound.supplyDoses - used)
  }

  /// Warns before logging a second dose soon after the last one (brief STK-04).
  static func doubleDoseWarning(
    for compound: StackCompound, at time: Date
  ) -> DoubleDoseGuard.Warning? {
    let last = compound.doses.compactMap(\.takenAt).filter { $0 <= time }.max()
    return DoubleDoseGuard.check(
      lastTaken: last, now: time, expectedIntervalHours: expectedIntervalHours(compound))
  }

  static func expectedIntervalHours(_ compound: StackCompound) -> Double {
    switch compound.repeatPattern {
    case .daily: 24
    case .everyNDays: Double(max(1, compound.intervalDays)) * 24
    case .weekly: 7 * 24
    case .weekdays: compound.weekdays.isEmpty ? 7 * 24 : 7 * 24 / Double(compound.weekdays.count)
    case .asNeeded: 0
    }
  }

  /// Whether the illustrative curve may be drawn: a positive half-life with a stated source.
  static func canShowLevel(_ compound: StackCompound) -> Bool {
    guard let hours = compound.halfLifeHours, hours > 0 else { return false }
    return !compound.halfLifeSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// The illustrative active amount over `range`, sampled `points` times, in the compound's
  /// own unit. Nil when the curve is disabled or no dose has a readable amount.
  static func levelSeries(
    for compound: StackCompound, in range: ClosedRange<Date>, points: Int = 60
  ) -> [(date: Date, amount: Double)]? {
    guard canShowLevel(compound), points > 1 else { return nil }
    let events = compound.doses.compactMap { dose -> DoseEvent? in
      guard let time = dose.takenAt, let amount = dose.amount else { return nil }
      return DoseEvent(time: time, amount: NSDecimalNumber(decimal: amount).doubleValue)
    }
    guard !events.isEmpty else { return nil }
    let span = range.upperBound.timeIntervalSince(range.lowerBound)
    return (0..<points).compactMap { index in
      let date = range.lowerBound.addingTimeInterval(span * Double(index) / Double(points - 1))
      return ActiveLevelModel.level(
        at: date, doses: events, halfLifeHours: compound.halfLifeHours
      ).map { (date, $0) }
    }
  }

  static func localDate(_ date: Date, calendar: Calendar) -> LocalDate {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return LocalDate(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1)
  }
}
