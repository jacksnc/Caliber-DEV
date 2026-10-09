import XCTest
@testable import TrainingCore

final class LocalDateTests: XCTestCase {
    func testKnownEpochDays() {
        XCTAssertEqual(LocalDate(year: 1970, month: 1, day: 1).epochDay, 0)
        XCTAssertEqual(LocalDate(year: 2000, month: 3, day: 1).epochDay, 11_017)
        XCTAssertEqual(LocalDate(year: 2026, month: 10, day: 9).epochDay, 20_735)
    }

    func testWeekdays() {
        XCTAssertEqual(LocalDate(year: 1970, month: 1, day: 1).isoWeekday, 4)   // Thursday
        XCTAssertEqual(LocalDate(year: 2000, month: 2, day: 29).isoWeekday, 2)  // Tuesday
        XCTAssertEqual(LocalDate(year: 2026, month: 10, day: 9).isoWeekday, 5)  // Friday
    }

    func testStartOfWeek() {
        let friday = LocalDate(year: 2026, month: 10, day: 9)
        XCTAssertEqual(friday.startOfWeek(), LocalDate(year: 2026, month: 10, day: 5))
        XCTAssertEqual(friday.startOfWeek(firstWeekday: 7), LocalDate(year: 2026, month: 10, day: 4))
        let monday = LocalDate(year: 2026, month: 10, day: 5)
        XCTAssertEqual(monday.startOfWeek(), monday)
    }

    func testAddingDaysAcrossMonthsAndYears() {
        XCTAssertEqual(LocalDate(year: 2024, month: 2, day: 28).addingDays(2), LocalDate(year: 2024, month: 3, day: 1))
        XCTAssertEqual(LocalDate(year: 2026, month: 12, day: 31).addingDays(1), LocalDate(year: 2027, month: 1, day: 1))
        XCTAssertEqual(LocalDate(year: 2027, month: 1, day: 1).addingDays(-1), LocalDate(year: 2026, month: 12, day: 31))
    }

    func testRoundTripAndContinuityAcrossTwoCenturies() {
        // 1900-01-01 is epoch day -25567; 2100-01-01 is 47482.
        for day in -25_567..<47_482 {
            let a = LocalDate(epochDay: day)
            let b = LocalDate(epochDay: day + 1)
            XCTAssertEqual(a.epochDay, day)
            let sameMonth = a.year == b.year && a.month == b.month && b.day == a.day + 1
            XCTAssertTrue(sameMonth || b.day == 1, "\(a) -> \(b)")
            XCTAssertEqual(b.isoWeekday, a.isoWeekday % 7 + 1)
        }
    }

    func testOrderingAndDescription() {
        XCTAssertLessThan(LocalDate(year: 2026, month: 10, day: 9), LocalDate(year: 2026, month: 10, day: 10))
        XCTAssertEqual(LocalDate(year: 2026, month: 10, day: 9).description, "2026-10-09")
        XCTAssertEqual(LocalDate(year: 99, month: 1, day: 5).description, "0099-01-05")
    }
}
