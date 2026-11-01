#if DEBUG
  import CaliberCore
  import Foundation
  import SwiftUI
  import WidgetKit

  /// Explicitly fictional mock snapshots for WidgetKit previews and testing.
  /// These values are fictional sample data and are not derived from user health records or actual personal data.
  public enum WidgetPreviewFixtures {
    public static let fixedCalendar: Calendar = {
      var cal = Calendar(identifier: .gregorian)
      cal.timeZone = .current
      return cal
    }()

    public static let referenceNow = Date.now

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
      let staleGeneratedAt = referenceNow.addingTimeInterval(-10800)
      let nutrition = NutritionWidgetValues(
        calories: 850,
        proteinGrams: 65,
        carbohydrateGrams: 90,
        fatGrams: 28
      )
      // Reuse the real constructor: generation may be yesterday, and expiry
      // must still stop at that day's midnight rather than crossing into today.
      return NutritionWidgetSnapshot.daily(
        nutrition: nutrition, at: staleGeneratedAt, timeZone: fixedCalendar.timeZone
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

  #Preview(
    as: .systemSmall,
    widget: {
      CaliberNutritionWidget()
    },
    timeline: {
      NutritionWidgetEntry(
        date: WidgetPreviewFixtures.referenceNow, snapshot: WidgetPreviewFixtures.fictionalCurrent)
    })

  #Preview(
    as: .systemMedium,
    widget: {
      CaliberNutritionWidget()
    },
    timeline: {
      NutritionWidgetEntry(
        date: WidgetPreviewFixtures.referenceNow, snapshot: WidgetPreviewFixtures.fictionalCurrent)
      NutritionWidgetEntry(
        date: WidgetPreviewFixtures.referenceNow.addingTimeInterval(7200),
        snapshot: WidgetPreviewFixtures.fictionalCurrent)
    })
#endif
