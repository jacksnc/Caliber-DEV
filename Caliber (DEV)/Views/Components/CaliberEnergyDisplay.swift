import CaliberCore
import Foundation

/// Read-only energy text in the person's saved unit.
///
/// Stored foods, entries, label facts, goals and overrides stay in canonical kilocalories.
/// This converts once, with `UnitFormatting.energy`, at the moment a figure is shown, and
/// returns text only, so a rounded display figure can never feed back into arithmetic.
/// Numeric editors keep their source kcal values and do not use it.
struct CaliberEnergyDisplay: Equatable, Sendable {
  let unit: EnergyUnit
  let locale: Locale

  init(unit: EnergyUnit, locale: Locale = .current) {
    self.unit = unit
    self.locale = locale
  }

  /// The figure alone. kcal keeps the exact recorded value ("100.25"), as before. kJ is a
  /// derived conversion, so it shows at most one decimal ("419.4", "6,117").
  func number(_ kilocalories: Double) -> String {
    let shown = UnitFormatting.energy(kilocalories, unit: unit)
    switch unit {
    case .kilocalories: return NutritionInput.format(shown, locale: locale)
    case .kilojoules: return UnitFormatting.number(shown, locale: locale, fractionDigits: 1)
    }
  }

  /// The compact unit label beside a figure: "kcal" or "kJ".
  var symbol: String { unit.rawValue }

  /// The unit inside a sentence such as "1 food · 420 calories" or "of 9,832 kJ".
  var sentenceUnit: String {
    switch unit {
    case .kilocalories: "calories"
    case .kilojoules: "kJ"
    }
  }

  /// The unit VoiceOver reads: "calories" or "kilojoules".
  var spokenUnit: String {
    switch unit {
    case .kilocalories: "calories"
    case .kilojoules: "kilojoules"
    }
  }

  /// "100.25 kcal" or "419.4 kJ".
  func short(_ kilocalories: Double) -> String { "\(number(kilocalories)) \(symbol)" }

  /// "100.25 calories" or "419.4 kJ".
  func sentence(_ kilocalories: Double) -> String {
    "\(number(kilocalories)) \(sentenceUnit)"
  }

  /// "100.25 calories" or "419.4 kilojoules".
  func spoken(_ kilocalories: Double) -> String { "\(number(kilocalories)) \(spokenUnit)" }

  /// Keeps a small positive over-goal amount from rounding down to zero in kJ.
  func aboveGoalNumber(_ kilocalories: Double) -> String {
    let shown = number(kilocalories)
    guard unit == .kilojoules, kilocalories > 0, shown == "0" else { return shown }
    let threshold = UnitFormatting.number(0.1, locale: locale, fractionDigits: 1)
    return "<\(threshold)"
  }
}
