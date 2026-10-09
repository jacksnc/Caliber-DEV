import Foundation

/// A calendar date with no time zone, as recorded at the moment of logging (brief §9.1: all day and
/// week aggregation uses the local date, never UTC midnight). Pure integer arithmetic.
public struct LocalDate: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Days since 1970-01-01.
    public init(epochDay: Int) {
        let z = epochDay + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        let y = yoe + era * 400 + (m <= 2 ? 1 : 0)
        self.init(year: y, month: m, day: d)
    }

    public var epochDay: Int {
        let yy = month <= 2 ? year - 1 : year
        let era = (yy >= 0 ? yy : yy - 399) / 400
        let yoe = yy - era * 400
        let mp = month > 2 ? month - 3 : month + 9
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    /// ISO weekday: 1 = Monday ... 7 = Sunday.
    public var isoWeekday: Int {
        ((epochDay % 7) + 7 + 3) % 7 + 1
    }

    public func addingDays(_ days: Int) -> LocalDate {
        LocalDate(epochDay: epochDay + days)
    }

    /// First day of the week containing this date. `firstWeekday` uses ISO numbering (1 = Monday ... 7 = Sunday).
    public func startOfWeek(firstWeekday: Int = 1) -> LocalDate {
        let offset = (isoWeekday - firstWeekday + 7) % 7
        return addingDays(-offset)
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        lhs.epochDay < rhs.epochDay
    }

    public var description: String {
        func pad(_ value: Int, _ width: Int) -> String {
            let text = String(value)
            return String(repeating: "0", count: max(0, width - text.count)) + text
        }
        return "\(pad(year, 4))-\(pad(month, 2))-\(pad(day, 2))"
    }
}
