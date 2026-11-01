import Foundation
import Testing

@testable import CaliberCore

private let widgetZone = TimeZone(identifier: "America/New_York")!
private let widgetValues = NutritionWidgetValues(
  calories: 130, proteinGrams: 20, carbohydrateGrams: 6, fatGrams: 3)
private func widgetDate(_ string: String) -> Date { ISO8601DateFormatter().date(from: string)! }

@Test func widgetDefaultsArePrivateAndContainNoNutrition() throws {
  let snapshot = NutritionWidgetSnapshot.privateSnapshot(at: .now)
  #expect(snapshot.nutrition == nil)
  #expect(snapshot.displayState(at: .now) == .private)
  let data = try JSONEncoder().encode(snapshot)
  #expect(!String(decoding: data, as: UTF8.self).contains("calories"))
}

@Test func widgetRoundTripPreservesReportedCaloriesAndExactExpiry() throws {
  let now = widgetDate("2026-11-01T17:00:00Z")
  let snapshot = NutritionWidgetSnapshot.daily(
    nutrition: widgetValues, at: now, timeZone: widgetZone)
  let copy = try JSONDecoder().decode(
    NutritionWidgetSnapshot.self, from: JSONEncoder().encode(snapshot))
  #expect(copy == snapshot)
  #expect(copy.nutrition?.calories == 130)  // Not 4P + 4C + 9F (131).
  #expect(copy.displayState(at: now, timeZone: widgetZone) == .current)
  #expect(copy.displayState(at: copy.expiresAt, timeZone: widgetZone) == .stale)
  #expect(copy.displayState(at: now.addingTimeInterval(-1), timeZone: widgetZone) == .stale)
  #expect(copy.displayState(at: now, timeZone: TimeZone(secondsFromGMT: 0)!) == .stale)
}

@Test(arguments: ["2026-03-09T03:50:00Z", "2026-11-02T04:50:00Z"])
func widgetExpiresAtLocalMidnightAcrossDST(_ text: String) {
  let now = widgetDate(text)
  let snapshot = NutritionWidgetSnapshot.daily(
    nutrition: widgetValues, at: now, timeZone: widgetZone)
  #expect(snapshot.expiresAt.timeIntervalSince(now) == 600)
  #expect(snapshot.displayState(at: now, timeZone: widgetZone) == .current)
  #expect(snapshot.displayState(at: snapshot.expiresAt, timeZone: widgetZone) == .stale)
}

@Test(arguments: [-1.0, Double.nan, Double.infinity])
func widgetRejectsInvalidNutrition(_ value: Double) {
  let now = Date.now
  let snapshot = NutritionWidgetSnapshot.daily(
    nutrition: .init(calories: value, proteinGrams: 0, carbohydrateGrams: 0, fatGrams: 0),
    at: now, timeZone: widgetZone)
  #expect(snapshot.displayState(at: now, timeZone: widgetZone) == .unavailable)
}

@Test func widgetRejectsTamperedDecodedDatesAndZones() {
  let now = widgetDate("2026-11-01T17:00:00Z")
  for zone in [widgetZone.identifier, "invalid-zone"] {
    let snapshot = NutritionWidgetSnapshot(
      generatedAt: now, expiresAt: now.addingTimeInterval(86400), dayStart: now,
      timeZoneIdentifier: zone, nutrition: widgetValues)
    #expect(snapshot.displayState(at: now, timeZone: widgetZone) == .unavailable)
  }
}
