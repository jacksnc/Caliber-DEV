import CaliberCore
import Foundation
import XCTest

@testable import Caliber__DEV_

@MainActor
final class SeasonalAppearanceModelTests: XCTestCase {
  func testClockRefreshActivatesAndRemovesChristmas() {
    var now = ISO8601DateFormatter().date(from: "2026-12-01T04:59:59Z")!
    let zone = TimeZone(identifier: "America/New_York")!
    let model = SeasonalAppearanceModel(now: { now }, timeZone: { zone })
    XCTAssertEqual(model.appearance, .standard)
    now = now.addingTimeInterval(1)
    model.refresh()
    XCTAssertEqual(model.appearance, .christmas)
    now = ISO8601DateFormatter().date(from: "2027-01-01T05:00:00Z")!
    model.refresh()
    XCTAssertEqual(model.appearance, .standard)
  }

  func testTimezoneRefreshAndClockReversalDoNotLeaveAStickySeason() {
    var now = ISO8601DateFormatter().date(from: "2026-11-30T12:30:00Z")!
    var zone = TimeZone(identifier: "Pacific/Kiritimati")!
    let model = SeasonalAppearanceModel(now: { now }, timeZone: { zone })
    XCTAssertEqual(model.appearance, .christmas)
    zone = TimeZone(identifier: "Pacific/Honolulu")!
    model.refresh()
    XCTAssertEqual(model.appearance, .standard)
    zone = TimeZone(identifier: "Pacific/Kiritimati")!
    now = ISO8601DateFormatter().date(from: "2026-11-01T00:00:00Z")!
    model.refresh()
    XCTAssertEqual(model.appearance, .standard)
  }
}
