import CaliberCore
import Foundation

/// Calendar periods are measured in local dates, never in the number of available records.
enum ChartPeriod: String, CaseIterable, Sendable {
  case week, month, quarter, year
  var componentAndCount: (Calendar.Component, Int) {
    switch self {
    case .week: (.day, 7)
    case .month: (.month, 1)
    case .quarter: (.month, 3)
    case .year: (.year, 1)
    }
  }
}

struct CalendarChartWindow: Sendable {
  struct Mark: Identifiable, Sendable {
    let observation: ChartObservation
    let segment: Int
    var id: String { observation.id }
  }
  struct Day: Identifiable, Sendable {
    let date: Date
    let observations: [ChartObservation]
    var id: Date { date }
  }
  let observations: [ChartObservation]
  let marks: [Mark]
  let days: [Day]
  let loggedDayCount: Int
  let dateDomain: ClosedRange<Date>?
  var valid: [ChartObservation] { marks.map(\.observation) }
  var dayCount: Int { days.count }

  init(observations input: [ChartObservation], period: ChartPeriod, calendar: Calendar) {
    // Non-finite dates/values are not plotted. A bad value still leaves a visible gap.
    let sorted = input.filter { $0.date.timeIntervalSince1970.isFinite }
      .sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
    let (component, count) = period.componentAndCount
    guard let latest = sorted.last?.date,
      let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: latest)),
      let start = calendar.date(byAdding: component, value: -count, to: end),
      let countOfDays = calendar.dateComponents([.day], from: start, to: end).day,
      (1...400).contains(countOfDays)
    else {
      observations = []
      marks = []
      days = []
      loggedDayCount = 0
      dateDomain = nil
      return
    }
    let selected = sorted.filter { $0.date >= start && $0.date < end }
    observations = selected
    dateDomain = start...end
    let grouped = Dictionary(grouping: selected) { calendar.startOfDay(for: $0.date) }
    days = (0..<countOfDays).compactMap { offset in
      guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
      return Day(date: day, observations: grouped[day, default: []])
    }
    loggedDayCount =
      grouped.values.filter { records in records.contains { $0.value?.isFinite == true } }.count
    var segment = 0
    var previousValidDate: Date?
    var nextMarks: [Mark] = []
    for observation in selected {
      guard observation.value?.isFinite == true else {
        segment += 1
        previousValidDate = nil
        continue
      }
      if let previousValidDate,
        let separation = calendar.dateComponents(
          [.day], from: calendar.startOfDay(for: previousValidDate),
          to: calendar.startOfDay(for: observation.date)
        ).day, separation > 1
      {
        // A sparse series must not draw through days that were never supplied.
        segment += 1
      }
      nextMarks.append(Mark(observation: observation, segment: segment))
      previousValidDate = observation.date
    }
    marks = nextMarks
  }
}
