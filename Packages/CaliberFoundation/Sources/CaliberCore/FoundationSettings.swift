import Foundation

public enum AppTheme: String, Codable, CaseIterable, Sendable { case system, light, dark, oled }
public enum MassUnit: String, Codable, CaseIterable, Sendable {
  case kilograms = "kg"
  case pounds = "lb"
  public func fromKilograms(_ value: Double) -> Double {
    self == .kilograms ? value : value / 0.45359237
  }
  public func kilograms(from value: Double) -> Double {
    self == .kilograms ? value : value * 0.45359237
  }
}
public enum DistanceUnit: String, Codable, CaseIterable, Sendable {
  case centimeters = "cm"
  case inches = "in"
}
public enum EnergyUnit: String, Codable, CaseIterable, Sendable {
  case kilocalories = "kcal"
  case kilojoules = "kJ"
}
public enum VolumeUnit: String, Codable, CaseIterable, Sendable {
  case milliliters = "mL"
  case fluidOunces = "US fl oz"
}
public enum TemperatureUnit: String, Codable, CaseIterable, Sendable {
  case celsius = "°C"
  case fahrenheit = "°F"
}
public enum WeekStart: Int, Codable, CaseIterable, Sendable {
  case sunday = 1
  case monday = 2
  case saturday = 7
}

/// These preferences contain no health records. UserDefaults is appropriate for their storage.
public struct FoundationSettings: Codable, Equatable, Sendable {
  public var theme: AppTheme = .dark
  public var massUnit: MassUnit = .pounds
  public var distanceUnit: DistanceUnit = .inches
  public var energyUnit: EnergyUnit = .kilocalories
  public var volumeUnit: VolumeUnit = .milliliters
  public var temperatureUnit: TemperatureUnit = .fahrenheit
  public var weekStart: WeekStart = .monday
  public var localeIdentifier: String = Locale.current.identifier
  public var hideNumbers = false
  public var ageConfirmed = false
  public var disclaimerAccepted = false
  public init() {}
  public var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.locale = Locale(identifier: localeIdentifier)
    value.firstWeekday = weekStart.rawValue
    return value
  }
}

public enum QuantityError: Error, Equatable { case invalidNumber, negative, unknownUnit }

/// Keep the entered text/unit so display rounding cannot rewrite historical input.
public struct EnteredMass: Codable, Equatable, Sendable {
  public let enteredText: String
  public let unit: MassUnit
  public let kilograms: Double
  public init(text: String, unit: MassUnit, locale: Locale = .current) throws {
    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .decimal
    formatter.isLenient = false
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    // Reject partial parses and grouping ambiguity in editable input. Display formatting can group digits.
    let separator = NSRegularExpression.escapedPattern(for: formatter.decimalSeparator ?? ".")
    let pattern = "^[+-]?(?:[0-9]+(?:" + separator + "[0-9]*)?|" + separator + "[0-9]+)$"
    guard trimmed.range(of: pattern, options: .regularExpression) != nil,
      let number = formatter.number(from: trimmed)?.doubleValue, number.isFinite
    else { throw QuantityError.invalidNumber }
    guard number >= 0 else { throw QuantityError.negative }
    let result = unit.kilograms(from: number)
    guard result.isFinite else { throw QuantityError.invalidNumber }
    enteredText = text
    self.unit = unit
    kilograms = result
  }
}

public enum UnitFormatting {
  public static func number(_ value: Double, locale: Locale, fractionDigits: Int = 1) -> String {
    guard value.isFinite else { return "—" }
    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = max(0, min(6, fractionDigits))
    formatter.minimumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "—"
  }
  public static func energy(_ kcal: Double, unit: EnergyUnit) -> Double {
    unit == .kilocalories ? kcal : kcal * 4.184
  }
  public static func length(_ cm: Double, unit: DistanceUnit) -> Double {
    unit == .centimeters ? cm : cm / 2.54
  }
  public static func volume(_ ml: Double, unit: VolumeUnit) -> Double {
    unit == .milliliters ? ml : ml / 29.5735295625
  }
  public static func temperature(_ celsius: Double, unit: TemperatureUnit) -> Double {
    unit == .celsius ? celsius : celsius * 9 / 5 + 32
  }
}
