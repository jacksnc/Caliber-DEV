import XCTest
import CaliberTime
@testable import StackCore

final class ScheduleEngineTests: XCTestCase {
    private func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        guard let zone = TimeZone(identifier: identifier) else { fatalError("unknown zone \(identifier)") }
        calendar.timeZone = zone
        return calendar
    }

    private var newYork: Calendar { calendar("America/New_York") }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> LocalDate { LocalDate(year: y, month: m, day: d) }

    /// [start of `from`, start of the day after `to`) in the calendar's zone.
    private func range(_ from: LocalDate, _ to: LocalDate, _ calendar: Calendar) -> Range<Date> {
        let start = ScheduleEngine.instant(on: from, minutesOfDay: 0, calendar: calendar)!
        let end = ScheduleEngine.instant(on: to.addingDays(1), minutesOfDay: 0, calendar: calendar)!
        return start..<end
    }

    private func dates(_ schedule: Schedule, _ from: LocalDate, _ to: LocalDate, calendar: Calendar? = nil) -> [LocalDate] {
        let cal = calendar ?? newYork
        return ScheduleEngine.occurrences(of: schedule, in: range(from, to, cal), userCalendar: cal).map { $0.date }
    }

    private func schedule(_ recurrence: Recurrence, start: LocalDate, times: [Int] = [480]) -> Schedule {
        Schedule(startDate: start, recurrence: recurrence, timesOfDay: times)
    }

    // MARK: recurrences

    func testDailyAtEightAM() {
        let cal = newYork
        let s = schedule(.daily, start: day(2026, 10, 5))
        let found = ScheduleEngine.occurrences(of: s, in: range(day(2026, 10, 5), day(2026, 10, 7), cal), userCalendar: cal)
        XCTAssertEqual(found.map { $0.date }, [day(2026, 10, 5), day(2026, 10, 6), day(2026, 10, 7)])
        for occurrence in found {
            let c = cal.dateComponents([.hour, .minute], from: occurrence.scheduledAt)
            XCTAssertEqual(c.hour, 8)
            XCTAssertEqual(c.minute, 0)
        }
    }

    func testEveryOtherDay() {
        let s = schedule(.everyNDays(2), start: day(2026, 10, 1))
        XCTAssertEqual(dates(s, day(2026, 10, 1), day(2026, 10, 7)),
                       [day(2026, 10, 1), day(2026, 10, 3), day(2026, 10, 5), day(2026, 10, 7)])
    }

    func testTwiceAWeekOnMondayAndThursday() {
        let s = schedule(.weekdays([1, 4]), start: day(2026, 10, 1))
        XCTAssertEqual(dates(s, day(2026, 10, 5), day(2026, 10, 11)), [day(2026, 10, 5), day(2026, 10, 8)])
    }

    func testWeeklyAndBiweeklyKeepTheStartWeekday() {
        let weekly = schedule(.everyNWeeks(1), start: day(2026, 10, 9))
        XCTAssertEqual(dates(weekly, day(2026, 10, 1), day(2026, 10, 31)),
                       [day(2026, 10, 9), day(2026, 10, 16), day(2026, 10, 23), day(2026, 10, 30)])
        let biweekly = schedule(.everyNWeeks(2), start: day(2026, 10, 9))
        XCTAssertEqual(dates(biweekly, day(2026, 10, 1), day(2026, 11, 8)),
                       [day(2026, 10, 9), day(2026, 10, 23), day(2026, 11, 6)])
    }

    func testMonthlyClampsToShortMonths() {
        let s = schedule(.monthly, start: day(2026, 1, 31))
        XCTAssertEqual(dates(s, day(2026, 1, 1), day(2026, 4, 30)),
                       [day(2026, 1, 31), day(2026, 2, 28), day(2026, 3, 31), day(2026, 4, 30)])
        let leap = schedule(.monthly, start: day(2028, 1, 31))
        XCTAssertEqual(dates(leap, day(2028, 2, 1), day(2028, 2, 29)), [day(2028, 2, 29)])
    }

    func testFiveOnTwoOffCycle() {
        let s = schedule(.cycle(on: 5, off: 2), start: day(2026, 10, 5))
        XCTAssertEqual(dates(s, day(2026, 10, 5), day(2026, 10, 18)),
                       [5, 6, 7, 8, 9, 12, 13, 14, 15, 16].map { day(2026, 10, $0) })
    }

    func testAsNeededSchedulesNothing() {
        XCTAssertTrue(dates(schedule(.prn, start: day(2026, 10, 1)), day(2026, 10, 1), day(2026, 10, 31)).isEmpty)
    }

    func testStartAndEndDatesAreRespected() {
        var s = schedule(.daily, start: day(2026, 10, 1))
        s.endDate = day(2026, 10, 3)
        XCTAssertEqual(dates(s, day(2026, 9, 20), day(2026, 10, 10)), [day(2026, 10, 1), day(2026, 10, 2), day(2026, 10, 3)])
        XCTAssertTrue(dates(s, day(2026, 9, 20), day(2026, 9, 30)).isEmpty)
    }

    func testSeveralTimesPerDayAreSortedAndDeduplicated() {
        let cal = newYork
        let s = schedule(.daily, start: day(2026, 10, 5), times: [1200, 480, 480])
        let found = ScheduleEngine.occurrences(of: s, in: range(day(2026, 10, 5), day(2026, 10, 5), cal), userCalendar: cal)
        XCTAssertEqual(found.map { $0.minutesOfDay }, [480, 1200])
        XCTAssertLessThan(found[0].scheduledAt, found[1].scheduledAt)
    }

    // MARK: titration

    func testTitrationAmountsFollowTheLatestStep() throws {
        func d(_ text: String) -> Decimal { Decimal(string: text)! }
        var s = schedule(.everyNWeeks(1), start: day(2026, 10, 1))
        s.steps = [TitrationStep(effectiveFrom: day(2026, 10, 29), amount: d("0.5")),
                   TitrationStep(effectiveFrom: day(2026, 10, 1), amount: d("0.25"))]
        let cal = newYork
        let found = ScheduleEngine.occurrences(of: s, in: range(day(2026, 10, 1), day(2026, 11, 1), cal), userCalendar: cal)
        XCTAssertEqual(found.map { $0.date }, [1, 8, 15, 22, 29].map { day(2026, 10, $0) })
        XCTAssertEqual(found.map { $0.plannedAmount }, [d("0.25"), d("0.25"), d("0.25"), d("0.25"), d("0.5")])
        XCTAssertNil(ScheduleEngine.amount(on: day(2026, 9, 1), steps: s.steps))
    }

    // MARK: daylight saving and travel

    func testWallClockTimeSurvivesTheSpringForwardChange() {
        let cal = newYork
        let s = schedule(.daily, start: day(2026, 3, 6))
        let found = ScheduleEngine.occurrences(of: s, in: range(day(2026, 3, 6), day(2026, 3, 9), cal), userCalendar: cal)
        XCTAssertEqual(found.count, 4)
        for occurrence in found {
            let c = cal.dateComponents([.hour, .minute], from: occurrence.scheduledAt)
            XCTAssertEqual(c.hour, 8, "\(occurrence.date)")
            XCTAssertEqual(c.minute, 0)
        }
        // The Saturday-to-Sunday gap is 23 hours, Sunday-to-Monday 24.
        XCTAssertEqual(found[2].scheduledAt.timeIntervalSince(found[1].scheduledAt), 23 * 3600, accuracy: 1)
        XCTAssertEqual(found[3].scheduledAt.timeIntervalSince(found[2].scheduledAt), 24 * 3600, accuracy: 1)
    }

    func testATimeSkippedBySpringForwardMovesToTheNextValidTime() throws {
        let cal = newYork
        let instant = try XCTUnwrap(ScheduleEngine.instant(on: day(2026, 3, 8), minutesOfDay: 150, calendar: cal))  // 02:30
        let c = cal.dateComponents([.year, .month, .day, .hour], from: instant)
        XCTAssertEqual(c.day, 8)
        XCTAssertEqual(c.hour, 3)
    }

    func testATimeRepeatedByFallBackUsesTheFirstOccurrence() throws {
        let cal = newYork
        let instant = try XCTUnwrap(ScheduleEngine.instant(on: day(2026, 11, 1), minutesOfDay: 90, calendar: cal))  // 01:30
        XCTAssertEqual(cal.timeZone.secondsFromGMT(for: instant), -4 * 3600, "first pass is still daylight time")
        let c = cal.dateComponents([.hour, .minute], from: instant)
        XCTAssertEqual(c.hour, 1)
        XCTAssertEqual(c.minute, 30)
    }

    func testFixedAnchorKeepsHomeTimeWhileTheUserTravels() {
        let london = calendar("Europe/London")
        let cal = newYork
        var s = schedule(.daily, start: day(2026, 10, 5))
        s.anchor = .fixed(timeZoneIdentifier: "Europe/London")
        let found = ScheduleEngine.occurrences(of: s, in: range(day(2026, 10, 5), day(2026, 10, 6), cal), userCalendar: cal)
        XCTAssertEqual(found.count, 2)
        for occurrence in found {
            XCTAssertEqual(london.dateComponents([.hour, .minute], from: occurrence.scheduledAt).hour, 8)
            // 08:00 in London (BST) is 03:00 in New York (EDT).
            XCTAssertEqual(cal.dateComponents([.hour], from: occurrence.scheduledAt).hour, 3)
        }
    }

    func testFloatingAnchorFollowsTheUserToANewZone() {
        let tokyo = calendar("Asia/Tokyo")
        let s = schedule(.daily, start: day(2026, 10, 5))
        let found = ScheduleEngine.occurrences(of: s, in: range(day(2026, 10, 5), day(2026, 10, 5), tokyo), userCalendar: tokyo)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(tokyo.dateComponents([.hour], from: found[0].scheduledAt).hour, 8)
    }

    // MARK: state machine

    private let scheduled = Date(timeIntervalSince1970: 1_800_000_000)

    private func status(_ log: DoseLogEntry?, nowOffsetMinutes: Double) -> DoseStatus {
        DoseStateMachine.status(scheduledAt: scheduled, log: log, now: scheduled.addingTimeInterval(nowOffsetMinutes * 60))
    }

    func testStatusWithNothingLogged() {
        XCTAssertEqual(status(nil, nowOffsetMinutes: -10), .upcoming)
        XCTAssertEqual(status(nil, nowOffsetMinutes: 0), .due)
        XCTAssertEqual(status(nil, nowOffsetMinutes: 30), .due)
        XCTAssertEqual(status(nil, nowOffsetMinutes: 12 * 60), .due)
        XCTAssertEqual(status(nil, nowOffsetMinutes: 12 * 60 + 1), .missed)
    }

    func testStatusOnceLogged() {
        func taken(_ minutes: Double) -> DoseLogEntry { .taken(at: scheduled.addingTimeInterval(minutes * 60)) }
        XCTAssertEqual(status(taken(30), nowOffsetMinutes: 40), .takenOnTime)
        XCTAssertEqual(status(taken(60), nowOffsetMinutes: 70), .takenOnTime)
        XCTAssertEqual(status(taken(61), nowOffsetMinutes: 70), .takenLate)
        XCTAssertEqual(status(taken(180), nowOffsetMinutes: 200), .takenLate)
        XCTAssertEqual(status(taken(-180), nowOffsetMinutes: -100), .takenEarly)
        XCTAssertEqual(status(.skipped, nowOffsetMinutes: 30), .skipped)
        XCTAssertEqual(status(.skipped, nowOffsetMinutes: 3000), .skipped)
    }

    func testWeeklyDosesCanUseALongerMissedWindow() {
        let window = DoseWindow(graceMinutes: 180, missedAfterMinutes: 3 * 24 * 60)
        let twoDaysLate = scheduled.addingTimeInterval(2 * 24 * 3600)
        XCTAssertEqual(DoseStateMachine.status(scheduledAt: scheduled, log: nil, now: twoDaysLate, window: window), .due)
        let fourDaysLate = scheduled.addingTimeInterval(4 * 24 * 3600)
        XCTAssertEqual(DoseStateMachine.status(scheduledAt: scheduled, log: nil, now: fourDaysLate, window: window), .missed)
    }

    // MARK: double-dose guard

    func testDoubleDoseGuard() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func ago(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }

        let daily = try XCTUnwrap(DoubleDoseGuard.check(lastTaken: ago(2), now: now, expectedIntervalHours: 24))
        XCTAssertEqual(daily.hoursSinceLast, 2, accuracy: 1e-9)
        XCTAssertNil(DoubleDoseGuard.check(lastTaken: ago(7), now: now, expectedIntervalHours: 24))
        XCTAssertNotNil(DoubleDoseGuard.check(lastTaken: ago(30), now: now, expectedIntervalHours: 168))
        XCTAssertNil(DoubleDoseGuard.check(lastTaken: ago(50), now: now, expectedIntervalHours: 168))
        XCTAssertNotNil(DoubleDoseGuard.check(lastTaken: ago(0.5), now: now, expectedIntervalHours: 2))
        XCTAssertNil(DoubleDoseGuard.check(lastTaken: ago(1.5), now: now, expectedIntervalHours: 2))
        XCTAssertNil(DoubleDoseGuard.check(lastTaken: nil, now: now, expectedIntervalHours: 24))
        XCTAssertNil(DoubleDoseGuard.check(lastTaken: now.addingTimeInterval(3600), now: now, expectedIntervalHours: 24))
    }
}
