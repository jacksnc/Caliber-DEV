import Foundation
import Testing

@testable import CaliberCore

@Test func massPreservesInputAndConvertsExactly() throws {
  let value = try EnteredMass(text: "135.00", unit: .pounds, locale: Locale(identifier: "en_US"))
  #expect(value.enteredText == "135.00")
  #expect(abs(value.kilograms - 61.23496995) < 0.00000001)
  #expect(abs(MassUnit.pounds.fromKilograms(value.kilograms) - 135) < 0.00000001)
  #expect(
    try EnteredMass(text: "80,5", unit: .kilograms, locale: Locale(identifier: "de_DE")).kilograms
      == 80.5)
}
@Test(arguments: ["nan", "infinity", "-1", "82 kg", "", "12abc", "1.2.3"])
func invalidMassCannotBecomeAValidPrefix(_ text: String) {
  #expect(throws: (any Error).self) {
    try EnteredMass(text: text, unit: .pounds, locale: Locale(identifier: "en_US"))
  }
}
@Test func exactDimensionsRemainDistinct() {
  #expect(abs(UnitFormatting.energy(100, unit: .kilojoules) - 418.4) < 1e-10)
  #expect(UnitFormatting.length(2.54, unit: .inches) == 1)
  #expect(abs(UnitFormatting.volume(29.5735295625, unit: .fluidOunces) - 1) < 1e-12)
  #expect(UnitFormatting.temperature(0, unit: .fahrenheit) == 32)
}
@Test func settingsRoundTripAndCalendarWeekStart() throws {
  var settings = FoundationSettings()
  settings.weekStart = .saturday
  settings.hideNumbers = true
  #expect(
    try JSONDecoder().decode(FoundationSettings.self, from: JSONEncoder().encode(settings))
      == settings)
  #expect(settings.calendar.firstWeekday == 7)
}
@Test func everyP1FlagIsPresentAndDisabled() throws {
  let flags = try FeatureCatalog.bundled()
  #expect(flags.count == 116)
  #expect(Set(flags.map(\.id)).count == flags.count)
  #expect(flags.allSatisfy { !$0.default && !FeatureCatalog.isEnabled($0.id) })
  #expect(!FeatureCatalog.isEnabled("unknown"))
}
@Test func diagnosticsContainOnlyAllowlistedEventAndCorrelation() {
  let id = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
  #expect(
    SafeDiagnostics.record(.syncFailed, correlationID: id)
      == "event=syncFailed correlation=00000000-0000-4000-8000-000000000001")
}
@Test func uuidV7UsesTimestampAndIsUnique() {
  let date = Date(timeIntervalSince1970: 1_700_000_000)
  let ids = (0..<1000).map { _ in UUIDv7.make(date: date) }
  #expect(ids.allSatisfy(UUIDv7.isValid))
  #expect(Set(ids).count == ids.count)
  #expect(ids[0].hasPrefix("018bcfe5-6800-7"))
}

@Test(arguments: [
  Double.nan, Double.infinity, -Double.infinity, -1.0, Double.greatestFiniteMagnitude,
])
func uuidV7InvalidDatesDoNotTrap(_ seconds: Double) {
  #expect(UUIDv7.isValid(UUIDv7.make(date: Date(timeIntervalSince1970: seconds))))
}
