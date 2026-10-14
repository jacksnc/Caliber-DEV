import Foundation
import Testing

@testable import Caliber__DEV_

@Test(arguments: [(3, 9, 23.0), (11, 2, 25.0)])
func previousDiaryDayFollowsLocalCalendarAcrossDST(month: Int, day: Int, hours: Double) throws {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "America/New_York")!
  let selected = calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
  let previous = try #require(DiaryDay.previous(before: selected, calendar: calendar))
  #expect(selected.timeIntervalSince(previous) == hours * 3600)
  #expect(calendar.component(.day, from: previous) == day - 1)
  let last = try #require(DiaryDay.lastInstant(of: previous, calendar: calendar))
  #expect(calendar.isDate(last, inSameDayAs: previous))
  #expect(last < selected)
  #expect(!calendar.isDate(selected, inSameDayAs: previous))
}
