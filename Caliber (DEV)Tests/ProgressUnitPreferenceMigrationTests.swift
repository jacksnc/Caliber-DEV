import CaliberCore
import Foundation
import Testing

@testable import Caliber__DEV_

@MainActor
struct ProgressUnitPreferenceMigrationTests {
  @Test func laterLegacySelectionIsAdoptedOnceWithoutChangingOtherSettings() throws {
    let name = "Caliber.UnitMigration.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    var settings = FoundationSettings()
    settings.massUnit = .pounds
    settings.hideNumbers = true
    settings.localeIdentifier = "de_DE"
    defaults.set("kilograms", forKey: "progressWeightUnit")
    ProgressUnitPreferenceMigration.apply(to: &settings, defaults: defaults)
    #expect(settings.massUnit == .kilograms)
    #expect(settings.hideNumbers)
    #expect(settings.localeIdentifier == "de_DE")
    #expect(defaults.bool(forKey: ProgressUnitPreferenceMigration.marker))
    let persisted = try JSONDecoder().decode(
      FoundationSettings.self, from: #require(defaults.data(forKey: "foundation.settings.v1")))
    #expect(persisted == settings)
    // A future stale legacy write cannot take authority back from Settings.
    defaults.set("pounds", forKey: "progressWeightUnit")
    ProgressUnitPreferenceMigration.apply(to: &settings, defaults: defaults)
    #expect(settings.massUnit == .kilograms)
  }

  @Test func invalidLegacySelectionPreservesCanonicalPreference() {
    let name = "Caliber.UnitMigration.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    var settings = FoundationSettings()
    settings.massUnit = .kilograms
    defaults.set("invalid", forKey: "progressWeightUnit")
    ProgressUnitPreferenceMigration.apply(to: &settings, defaults: defaults)
    #expect(settings.massUnit == .kilograms)
  }
}
