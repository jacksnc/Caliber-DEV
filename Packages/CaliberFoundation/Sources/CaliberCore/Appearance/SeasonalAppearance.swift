import Foundation

public enum SeasonalAppearance: String, Equatable, Sendable { case standard, christmas }

/// Seasonal decoration follows the Gregorian date in the phone's current timezone.
/// It never changes a saved base theme, diary date, reminder or health calculation.
public enum SeasonalAppearancePolicy {
  public static func appearance(at date: Date, timeZone: TimeZone) -> SeasonalAppearance {
    guard date.timeIntervalSince1970.isFinite else { return .standard }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.component(.month, from: date) == 12 ? .christmas : .standard
  }

  public static func nextLocalMidnight(after date: Date, timeZone: TimeZone) -> Date? {
    guard date.timeIntervalSince1970.isFinite else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
  }

  public static func animatesSnow(
    appearance: SeasonalAppearance, isVisible: Bool, isActive: Bool,
    reduceMotion: Bool, reduceTransparency: Bool, increasedContrast: Bool,
    lowPower: Bool, motionEnabled: Bool
  ) -> Bool {
    appearance == .christmas && isVisible && isActive && motionEnabled
      && !reduceMotion && !reduceTransparency && !increasedContrast && !lowPower
  }
}
