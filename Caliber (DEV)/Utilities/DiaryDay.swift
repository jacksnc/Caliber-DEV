import Foundation

nonisolated enum DiaryDay {
  static func previous(before date: Date, calendar: Calendar) -> Date? {
    guard date.timeIntervalSinceReferenceDate.isFinite else { return nil }
    return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date))
  }
  static func lastInstant(of date: Date, calendar: Calendar) -> Date? {
    guard date.timeIntervalSinceReferenceDate.isFinite,
      let day = calendar.dateInterval(of: .day, for: date)
    else { return nil }
    return Date(timeIntervalSinceReferenceDate: day.end.timeIntervalSinceReferenceDate.nextDown)
  }
}
