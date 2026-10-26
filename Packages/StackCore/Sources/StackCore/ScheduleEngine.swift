import Foundation
import HeliosTime

// Schedule engine (brief STK-03): turns a protocol's recurrence into concrete dose occurrences,
// handling daylight-saving changes and travel (floating vs fixed time anchors), and classifies each
// occurrence as upcoming / due / taken / late / skipped / missed.

public enum Recurrence: Equatable, Sendable {
    case daily
    case everyNDays(Int)
    /// ISO weekdays, 1 = Monday ... 7 = Sunday. Covers "N times per week".
    case weekdays(Set<Int>)
    /// Same weekday as the start date, every `n` weeks (weekly = 1, biweekly = 2).
    case everyNWeeks(Int)
    /// Same day of the month as the start date; shorter months clamp to their last day.
    case monthly
    /// `on` consecutive days, then `off` days, repeating from the start date (e.g. 5 on / 2 off).
    case cycle(on: Int, off: Int)
    /// As needed: nothing is scheduled.
    case prn
}

public enum TimeAnchor: Equatable, Sendable {
    /// Local clock time in whatever time zone the user is in now ("8:00 wherever I am").
    case floating
    /// Clock time in a specific zone, even while travelling ("8:00 home time").
    case fixed(timeZoneIdentifier: String)
}

public struct TitrationStep: Equatable, Sendable {
    public let effectiveFrom: LocalDate
    public let amount: Decimal

    public init(effectiveFrom: LocalDate, amount: Decimal) {
        self.effectiveFrom = effectiveFrom
        self.amount = amount
    }
}

public struct Schedule: Equatable, Sendable {
    public var startDate: LocalDate
    public var endDate: LocalDate?
    public var recurrence: Recurrence
    /// Minutes after local midnight, e.g. 480 = 08:00.
    public var timesOfDay: [Int]
    public var anchor: TimeAnchor
    /// User-entered amounts by date. The engine only looks them up; it never proposes amounts.
    public var steps: [TitrationStep]

    public init(
        startDate: LocalDate,
        endDate: LocalDate? = nil,
        recurrence: Recurrence,
        timesOfDay: [Int],
        anchor: TimeAnchor = .floating,
        steps: [TitrationStep] = []
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.recurrence = recurrence
        self.timesOfDay = timesOfDay
        self.anchor = anchor
        self.steps = steps
    }
}

public struct Occurrence: Equatable, Sendable {
    public let date: LocalDate
    public let minutesOfDay: Int
    public let scheduledAt: Date
    public let plannedAmount: Decimal?
}

public enum ScheduleEngine {
    /// Occurrences whose instant lies in `range`, in time order.
    /// - Parameter userCalendar: the user's current calendar and time zone (used for `.floating` anchors).
    public static func occurrences(
        of schedule: Schedule,
        in range: Range<Date>,
        userCalendar: Calendar
    ) -> [Occurrence] {
        if case .prn = schedule.recurrence { return [] }

        var calendar = userCalendar
        if case let .fixed(identifier) = schedule.anchor, let zone = TimeZone(identifier: identifier) {
            calendar.timeZone = zone
        }

        guard let first = localDate(of: range.lowerBound, calendar: calendar),
              let last = localDate(of: range.upperBound, calendar: calendar) else { return [] }

        let times = Array(Set(schedule.timesOfDay)).sorted()
        var result: [Occurrence] = []
        var day = first.addingDays(-1).epochDay
        let lastDay = last.addingDays(1).epochDay

        while day <= lastDay {
            let date = LocalDate(epochDay: day)
            if matches(date, schedule: schedule) {
                for minutes in times {
                    guard let instant = instant(on: date, minutesOfDay: minutes, calendar: calendar),
                          range.contains(instant) else { continue }
                    result.append(Occurrence(
                        date: date,
                        minutesOfDay: minutes,
                        scheduledAt: instant,
                        plannedAmount: amount(on: date, steps: schedule.steps)
                    ))
                }
            }
            day += 1
        }
        return result.sorted { $0.scheduledAt < $1.scheduledAt }
    }

    /// Whether `date` is a scheduled day.
    public static func matches(_ date: LocalDate, schedule: Schedule) -> Bool {
        if date < schedule.startDate { return false }
        if let end = schedule.endDate, date > end { return false }
        let elapsed = date.epochDay - schedule.startDate.epochDay

        switch schedule.recurrence {
        case .daily:
            return true
        case let .everyNDays(n):
            return n >= 1 && elapsed % n == 0
        case let .weekdays(days):
            return days.contains(date.isoWeekday)
        case let .everyNWeeks(n):
            return n >= 1 && elapsed % (7 * n) == 0
        case .monthly:
            let target = min(schedule.startDate.day, daysInMonth(year: date.year, month: date.month))
            return date.day == target
        case let .cycle(on, off):
            guard on >= 1, off >= 0 else { return false }
            return elapsed % (on + off) < on
        case .prn:
            return false
        }
    }

    /// The amount in force on `date` (latest titration step starting on or before it).
    public static func amount(on date: LocalDate, steps: [TitrationStep]) -> Decimal? {
        steps.filter { $0.effectiveFrom <= date }.max(by: { $0.effectiveFrom < $1.effectiveFrom })?.amount
    }

    /// The instant of a wall-clock time on a date. A time skipped by a spring-forward change moves to the
    /// next valid time; a time repeated by a fall-back change uses its first occurrence.
    public static func instant(on date: LocalDate, minutesOfDay: Int, calendar: Calendar) -> Date? {
        var dayComponents = DateComponents()
        dayComponents.year = date.year
        dayComponents.month = date.month
        dayComponents.day = date.day
        guard let startOfDay = calendar.date(from: dayComponents) else { return nil }

        var wanted = DateComponents()
        wanted.hour = minutesOfDay / 60
        wanted.minute = minutesOfDay % 60
        wanted.second = 0
        guard let found = calendar.nextDate(
            after: startOfDay.addingTimeInterval(-1),
            matching: wanted,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) else { return nil }

        let landed = calendar.dateComponents([.year, .month, .day], from: found)
        if landed.year == date.year && landed.month == date.month && landed.day == date.day { return found }
        return startOfDay
    }

    static func localDate(of instant: Date, calendar: Calendar) -> LocalDate? {
        let c = calendar.dateComponents([.year, .month, .day], from: instant)
        guard let year = c.year, let month = c.month, let day = c.day else { return nil }
        return LocalDate(year: year, month: month, day: day)
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 2:
            let leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
            return leap ? 29 : 28
        case 4, 6, 9, 11:
            return 30
        default:
            return 31
        }
    }
}

// MARK: - Dose state machine

public struct DoseWindow: Equatable, Sendable {
    /// Taking a dose within this many minutes of its scheduled time counts as on time.
    public var graceMinutes: Int
    /// With nothing logged, a dose becomes "missed" this many minutes after its scheduled time.
    public var missedAfterMinutes: Int

    public init(graceMinutes: Int = 60, missedAfterMinutes: Int = 12 * 60) {
        self.graceMinutes = graceMinutes
        self.missedAfterMinutes = missedAfterMinutes
    }
}

public enum DoseLogEntry: Equatable, Sendable {
    case taken(at: Date)
    case skipped
}

public enum DoseStatus: Equatable, Sendable {
    case upcoming
    case due
    case takenOnTime
    case takenLate
    case takenEarly
    case skipped
    case missed
}

public enum DoseStateMachine {
    public static func status(
        scheduledAt: Date,
        log: DoseLogEntry?,
        now: Date,
        window: DoseWindow = DoseWindow()
    ) -> DoseStatus {
        let grace = Double(window.graceMinutes) * 60

        switch log {
        case .skipped?:
            return .skipped
        case let .taken(at)?:
            let delta = at.timeIntervalSince(scheduledAt)
            if delta > grace { return .takenLate }
            if delta < -grace { return .takenEarly }
            return .takenOnTime
        case nil:
            if now < scheduledAt { return .upcoming }
            let overdue = now.timeIntervalSince(scheduledAt)
            return overdue <= Double(window.missedAfterMinutes) * 60 ? .due : .missed
        }
    }
}

/// Double-dose guard (brief STK-04): warn when another dose is logged soon after the last one.
public enum DoubleDoseGuard {
    public struct Warning: Equatable, Sendable {
        public let hoursSinceLast: Double
    }

    /// Warns when less than max(1 hour, 25% of the expected interval) has passed since the last taken dose.
    public static func check(lastTaken: Date?, now: Date, expectedIntervalHours: Double) -> Warning? {
        guard let last = lastTaken, now >= last else { return nil }
        let hours = now.timeIntervalSince(last) / 3600
        let threshold = max(1, 0.25 * expectedIntervalHours)
        return hours < threshold ? Warning(hoursSinceLast: hours) : nil
    }
}
