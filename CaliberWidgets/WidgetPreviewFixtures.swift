import CaliberCore
import Foundation

/// Explicitly fictional mock snapshots for WidgetKit previews and testing.
/// These values are fictional sample data and are not derived from user health records or actual personal data.
public enum WidgetPreviewFixtures {
  public static let fixedCalendar: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
    return cal
  }()

  public static let referenceNow = Date(timeIntervalSince1970: 1_730_462_400)

  /// Fictional populated intake snapshot for current day.
  public static var fictionalCurrent: NutritionWidgetSnapshot {
    let nutrition = NutritionWidgetValues(
      calories: 1420,
      proteinGrams: 110,
      carbohydrateGrams: 145,
      fatGrams: 48
    )
    return NutritionWidgetSnapshot.daily(
      nutrition: nutrition,
      at: referenceNow,
      timeZone: fixedCalendar.timeZone
    )
  }

  /// Fictional all-zero intake snapshot ("0 calories logged").
  public static var fictionalZeroCurrent: NutritionWidgetSnapshot {
    let nutrition = NutritionWidgetValues(
      calories: 0,
      proteinGrams: 0,
      carbohydrateGrams: 0,
      fatGrams: 0
    )
    return NutritionWidgetSnapshot.daily(
      nutrition: nutrition,
      at: referenceNow,
      timeZone: fixedCalendar.timeZone
    )
  }

  /// Fictional private snapshot where sharing is turned off in Settings.
  public static var fictionalPrivate: NutritionWidgetSnapshot {
    NutritionWidgetSnapshot.privateSnapshot(
      at: referenceNow,
      timeZone: fixedCalendar.timeZone
    )
  }

  /// Fictional stale snapshot past freshness expiration (older than 2 hours).
  public static var fictionalStale: NutritionWidgetSnapshot {
    let day = fixedCalendar.startOfDay(for: referenceNow)
    let staleGeneratedAt = referenceNow.addingTimeInterval(-10800)
    let staleExpiresAt = staleGeneratedAt.addingTimeInterval(7200)
    let nutrition = NutritionWidgetValues(
      calories: 850,
      proteinGrams: 65,
      carbohydrateGrams: 90,
      fatGrams: 28
    )
    return NutritionWidgetSnapshot(
      generatedAt: staleGeneratedAt,
      expiresAt: staleExpiresAt,
      dayStart: day,
      timeZoneIdentifier: fixedCalendar.timeZone.identifier,
      nutrition: nutrition
    )
  }

  /// Fictional unavailable snapshot with unreadable/invalid data.
  public static var fictionalUnavailable: NutritionWidgetSnapshot {
    let day = fixedCalendar.startOfDay(for: referenceNow)
    return NutritionWidgetSnapshot(
      generatedAt: referenceNow,
      expiresAt: referenceNow.addingTimeInterval(3600),
      dayStart: day,
      timeZoneIdentifier: "Invalid/TimeZone_ID",
      nutrition: NutritionWidgetValues(
        calories: 1200,
        proteinGrams: 80,
        carbohydrateGrams: 120,
        fatGrams: 40
      )
    )
  }
}
