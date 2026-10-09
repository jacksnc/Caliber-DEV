import XCTest
@testable import TrainingCore

final class LoadRoundingTests: XCTestCase {
    private let kg: [Plate] = [2500, 2000, 1500, 1000, 500, 250, 125].map { Plate(size: $0, pairs: 2) }

    func testIncrementRounding() {
        let r = LoadRounding.increment(2.5)
        XCTAssertEqual(r.round(92.25), 92.5, accuracy: 1e-9)
        XCTAssertEqual(r.round(91.2), 90, accuracy: 1e-9)
        XCTAssertEqual(r.round(91.2, direction: .up), 92.5, accuracy: 1e-9)
        XCTAssertEqual(r.round(91.2, direction: .down), 90, accuracy: 1e-9)
        XCTAssertEqual(r.round(100, direction: .up), 100, accuracy: 1e-9)
        XCTAssertEqual(r.round(100, direction: .down), 100, accuracy: 1e-9)
    }

    func testNoRoundingAndInvalidStepAreIdentity() {
        XCTAssertEqual(LoadRounding.none.round(97.123), 97.123)
        XCTAssertEqual(LoadRounding.increment(0).round(97.123), 97.123)
    }

    func testPlateRoundingUsesTheRealInventory() {
        let r = LoadRounding.plates(bar: 20, inventory: kg)
        XCTAssertEqual(r.round(101), 100, accuracy: 1e-9)
        XCTAssertEqual(r.round(101, direction: .up), 102.5, accuracy: 1e-9)
        XCTAssertEqual(r.round(101, direction: .down), 100, accuracy: 1e-9)
        XCTAssertEqual(r.round(92.25), 92.5, accuracy: 1e-9)
        XCTAssertEqual(r.round(10), 20, accuracy: 1e-9, "below the bar snaps to the bar")
    }

    func testNumberFormatting() {
        XCTAssertEqual(formatNumber(102.5), "102.5")
        XCTAssertEqual(formatNumber(100), "100")
        XCTAssertEqual(formatNumber(92.25), "92.25")
        XCTAssertEqual(formatNumber(0.1 + 0.2), "0.3")
    }
}
