import Foundation
import Testing

@testable import CaliberCore

private func seasonDate(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

@Test(arguments: [
  ("2026-12-01T04:59:59Z", SeasonalAppearance.standard),
  ("2026-12-01T05:00:00Z", .christmas),
  ("2027-01-01T04:59:59Z", .christmas),
  ("2027-01-01T05:00:00Z", .standard),
  ("2027-12-01T05:00:00Z", .christmas),
])
func seasonalAppearanceChangesExactlyAtLocalDecemberBoundaries(
  _ text: String, _ expected: SeasonalAppearance
) {
  #expect(
    SeasonalAppearancePolicy.appearance(
      at: seasonDate(text), timeZone: TimeZone(identifier: "America/New_York")!) == expected)
}

@Test func seasonalAppearanceUsesPhoneTimezoneRatherThanUTCOrLocale() {
  let date = seasonDate("2026-11-30T12:30:00Z")
  #expect(
    SeasonalAppearancePolicy.appearance(
      at: date, timeZone: TimeZone(identifier: "Pacific/Kiritimati")!) == .christmas)
  #expect(
    SeasonalAppearancePolicy.appearance(
      at: date, timeZone: TimeZone(identifier: "Pacific/Honolulu")!) == .standard)
}

@Test(arguments: [
  ("2026-11-01T04:00:00Z", "2026-11-02T05:00:00Z"),
  ("2027-03-14T05:00:00Z", "2027-03-15T04:00:00Z"),
  ("2026-11-30T23:00:00Z", "2026-12-01T05:00:00Z"),
])
func seasonalClockSchedulesCalendarMidnightAcrossDST(_ now: String, _ next: String) {
  #expect(
    SeasonalAppearancePolicy.nextLocalMidnight(
      after: seasonDate(now), timeZone: TimeZone(identifier: "America/New_York")!)
      == seasonDate(next))
}

@Test func seasonalAppearanceFailsClosedForInvalidDate() {
  let invalid = Date(timeIntervalSince1970: .nan)
  #expect(SeasonalAppearancePolicy.appearance(at: invalid, timeZone: .current) == .standard)
  #expect(SeasonalAppearancePolicy.nextLocalMidnight(after: invalid, timeZone: .current) == nil)
}

@Test func seasonalSnowRequiresVisibleActiveDecemberAndHonorsAccessibilityAndPower() {
  func animates(
    season: SeasonalAppearance = .christmas, visible: Bool = true, active: Bool = true,
    reduceMotion: Bool = false, reduceTransparency: Bool = false, contrast: Bool = false,
    lowPower: Bool = false, enabled: Bool = true
  ) -> Bool {
    SeasonalAppearancePolicy.animatesSnow(
      appearance: season, isVisible: visible, isActive: active, reduceMotion: reduceMotion,
      reduceTransparency: reduceTransparency, increasedContrast: contrast,
      lowPower: lowPower, motionEnabled: enabled)
  }
  #expect(animates())
  #expect(!animates(season: .standard))
  #expect(!animates(visible: false))
  #expect(!animates(active: false))
  #expect(!animates(reduceMotion: true))
  #expect(!animates(reduceTransparency: true))
  #expect(!animates(contrast: true))
  #expect(!animates(lowPower: true))
  #expect(!animates(enabled: false))
}
