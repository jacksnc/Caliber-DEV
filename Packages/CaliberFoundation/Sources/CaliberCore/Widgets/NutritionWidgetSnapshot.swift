import Foundation

/// An allowlist of daily totals. Never carries diary records, names, photos or account data.
public struct NutritionWidgetValues: Codable, Equatable, Sendable {
  public let calories: Double
  public let proteinGrams: Double
  public let carbohydrateGrams: Double
  public let fatGrams: Double

  public init(calories: Double, proteinGrams: Double, carbohydrateGrams: Double, fatGrams: Double) {
    self.calories = calories
    self.proteinGrams = proteinGrams
    self.carbohydrateGrams = carbohydrateGrams
    self.fatGrams = fatGrams
  }

  fileprivate var isValid: Bool {
    [calories, proteinGrams, carbohydrateGrams, fatGrams].allSatisfy { $0.isFinite && $0 >= 0 }
  }
}

public enum NutritionWidgetDisplayState: Equatable, Sendable {
  case `private`, current, stale, unavailable
}

/// Short-lived presentation data, separate from the app database. Validate again after decoding.
public struct NutritionWidgetSnapshot: Codable, Equatable, Sendable {
  public let generatedAt: Date
  public let expiresAt: Date
  public let dayStart: Date
  public let timeZoneIdentifier: String
  public let nutrition: NutritionWidgetValues?

  public init(
    generatedAt: Date, expiresAt: Date, dayStart: Date,
    timeZoneIdentifier: String, nutrition: NutritionWidgetValues?
  ) {
    self.generatedAt = generatedAt
    self.expiresAt = expiresAt
    self.dayStart = dayStart
    self.timeZoneIdentifier = timeZoneIdentifier
    self.nutrition = nutrition
  }

  public static func privateSnapshot(at now: Date, timeZone: TimeZone = .current) -> Self {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return Self(
      generatedAt: now, expiresAt: now, dayStart: calendar.startOfDay(for: now),
      timeZoneIdentifier: timeZone.identifier, nutrition: nil)
  }

  /// Two-hour freshness ceiling, also capped at local midnight, including DST transitions.
  public static func daily(
    nutrition: NutritionWidgetValues, at now: Date, timeZone: TimeZone = .current
  ) -> Self {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let day = calendar.startOfDay(for: now)
    let midnight = calendar.date(byAdding: .day, value: 1, to: day) ?? now
    return Self(
      generatedAt: now, expiresAt: min(now.addingTimeInterval(7200), midnight), dayStart: day,
      timeZoneIdentifier: timeZone.identifier, nutrition: nutrition)
  }

  public func displayState(at now: Date, timeZone: TimeZone = .current)
    -> NutritionWidgetDisplayState
  {
    guard let nutrition else { return .private }
    guard nutrition.isValid,
      [generatedAt, expiresAt, dayStart, now].allSatisfy({ $0.timeIntervalSince1970.isFinite }),
      let sourceZone = TimeZone(identifier: timeZoneIdentifier)
    else { return .unavailable }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = sourceZone
    guard dayStart == calendar.startOfDay(for: generatedAt),
      let midnight = calendar.date(byAdding: .day, value: 1, to: dayStart),
      expiresAt > generatedAt, expiresAt <= midnight,
      expiresAt.timeIntervalSince(generatedAt) <= 7200
    else { return .unavailable }
    guard timeZone.identifier == timeZoneIdentifier, now >= generatedAt, now < expiresAt,
      calendar.isDate(now, inSameDayAs: dayStart)
    else { return .stale }
    return .current
  }
}
