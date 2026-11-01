import CaliberCore
import Foundation

/// The old check-in form wrote a separate preference. Every Settings save also
/// mirrored its unit there, so a different valid legacy value is the later choice.
/// Adopt it once, then keep FoundationSettings as the single authority.
enum ProgressUnitPreferenceMigration {
  static let marker = "progress.weightUnit.unified.v1"

  static func apply(to settings: inout FoundationSettings, defaults: UserDefaults) {
    guard !defaults.bool(forKey: marker) else { return }
    if let raw = defaults.string(forKey: "progressWeightUnit"), let unit = WeightUnit(rawValue: raw)
    {
      settings.massUnit = unit == .kilograms ? .kilograms : .pounds
    }
    guard let data = try? JSONEncoder().encode(settings) else { return }
    defaults.set(data, forKey: "foundation.settings.v1")
    defaults.set(true, forKey: marker)
  }
}
