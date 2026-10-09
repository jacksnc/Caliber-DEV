import CaliberCore
import Foundation
import Testing

@testable import CaliberCharts

struct CalendarChartWindowTests {
  private func calendar(_ zone: String = "GMT") -> Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(identifier: zone)!
    return value
  }
  private func date(_ value: String, calendar: Calendar = CalendarChartWindowTests().calendar())
    -> Date
  {
    let parts = value.split(separator: "-").map { Int($0)! }
    return calendar.date(
      from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))!
  }
  private func point(
    _ day: String, _ value: Double? = 80, id: String? = nil,
    calendar: Calendar = CalendarChartWindowTests().calendar()
  ) -> ChartObservation {
    ChartObservation(id: id ?? day, date: date(day, calendar: calendar), value: value)
  }

  @Test func weekMeansSevenCalendarDaysRatherThanSevenSparseRecords() {
    let records = [
      point("2026-01-01"), point("2026-01-10"), point("2026-01-25"), point("2026-01-31"),
    ]
    let result = CalendarChartWindow(observations: records, period: .week, calendar: calendar())
    #expect(result.observations.map(\.id) == ["2026-01-25", "2026-01-31"])
    #expect(result.dayCount == 7)
    #expect(result.loggedDayCount == 2)
    #expect(result.days.filter { $0.observations.isEmpty }.count == 5)
  }
  @Test func monthUsesActualLeapFebruaryBoundary() {
    let records = [point("2024-01-31"), point("2024-02-01"), point("2024-02-29")]
    let result = CalendarChartWindow(observations: records, period: .month, calendar: calendar())
    #expect(result.dayCount == 29)
    #expect(result.observations.map(\.id) == ["2024-02-01", "2024-02-29"])
    #expect(result.dateDomain?.lowerBound == calendar().startOfDay(for: date("2024-02-01")))
  }
  @Test func leapYearRetainsAll366DayBuckets() {
    let result = CalendarChartWindow(
      observations: [point("2024-12-31")], period: .year, calendar: calendar())
    #expect(result.dayCount == 366)
    #expect(result.dateDomain?.lowerBound == calendar().startOfDay(for: date("2024-01-01")))
  }
  @Test(arguments: ["2026-03-08", "2026-11-01"])
  func weekCoverageUsesLocalDaysAcrossDST(lastDate: String) {
    let localCalendar = calendar("America/New_York")
    let result = CalendarChartWindow(
      observations: [point(lastDate, calendar: localCalendar)], period: .week,
      calendar: localCalendar)
    #expect(result.dayCount == 7)
    #expect(Set(result.days.map(\.date)).count == 7)
    #expect(result.days.allSatisfy { localCalendar.component(.hour, from: $0.date) == 0 })
    let expectedHours: Double = lastDate == "2026-03-08" ? 167 : 169
    #expect(
      result.dateDomain!.upperBound.timeIntervalSince(result.dateDomain!.lowerBound) / 3600
        == expectedHours)
  }
  @Test func sparseMissingDatesSplitLinesWithoutInventingZeroes() {
    let result = CalendarChartWindow(
      observations: [point("2026-01-01"), point("2026-01-02"), point("2026-01-05")], period: .week,
      calendar: calendar())
    #expect(result.marks.map(\.segment) == [0, 0, 1])
    #expect(
      result.days.first { calendar().isDate($0.date, inSameDayAs: date("2026-01-03")) }?
        .observations.isEmpty == true)
    #expect(result.valid.allSatisfy { $0.value == 80 })
  }
  @Test func explicitMissingAndInvalidValuesBreakSegments() {
    let result = CalendarChartWindow(
      observations: [
        point("2026-01-01"), point("2026-01-02", nil), point("2026-01-03"),
        point("2026-01-04", .nan), point("2026-01-05"), point("2026-01-06", .infinity),
      ], period: .week, calendar: calendar())
    #expect(result.marks.map(\.segment) == [0, 1, 2])
    #expect(result.loggedDayCount == 3)
    #expect(result.observations.count == 6)
  }
  @Test func repeatedSameDayValuesCountAsOneLoggedDayAndStayInTable() {
    let a = point("2026-01-31", 80, id: "a")
    let b = ChartObservation(id: "b", date: a.date.addingTimeInterval(1800), value: 81)
    let result = CalendarChartWindow(observations: [b, a], period: .week, calendar: calendar())
    #expect(result.loggedDayCount == 1)
    #expect(result.valid.count == 2)
    #expect(result.days.last?.observations.map(\.id) == ["a", "b"])
    #expect(result.marks.map(\.segment) == [0, 0])
  }
  @Test func emptyInputHasNoFabricatedDomainOrCoverage() {
    let result = CalendarChartWindow(observations: [], period: .month, calendar: calendar())
    #expect(result.dateDomain == nil)
    #expect(result.dayCount == 0)
    #expect(result.loggedDayCount == 0)
    #expect(result.marks.isEmpty)
  }
  @Test func nonfiniteDatesAreExcludedAndAllMissingDatesAreStillVisible() {
    let invalid = ChartObservation(id: "invalid", date: Date(timeIntervalSince1970: .nan), value: 5)
    let result = CalendarChartWindow(
      observations: [invalid, point("2026-01-31", nil)], period: .week, calendar: calendar())
    #expect(result.dayCount == 7)
    #expect(result.observations.count == 1)
    #expect(result.loggedDayCount == 0)
    #expect(result.marks.isEmpty)
  }
}
