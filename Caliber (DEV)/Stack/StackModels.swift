import Foundation
import SwiftData

/// Units a person can record a dose in (brief STK-02). They are labels only: the app never
/// converts between them, because IU, pen clicks and syringe markings are different
/// dimensions from mass or volume (D17).
enum StackUnit: String, CaseIterable, Identifiable, Codable {
  case mcg, mg, iu, ml, units, clicks, tablets, capsules

  var id: String { rawValue }

  var symbol: String {
    switch self {
    case .mcg: "mcg"
    case .mg: "mg"
    case .iu: "IU"
    case .ml: "mL"
    case .units: "units"
    case .clicks: "pen clicks"
    case .tablets: "tablets"
    case .capsules: "capsules"
    }
  }
}

/// How the product is supplied. Used for wording and icons only.
enum StackForm: String, CaseIterable, Identifiable, Codable {
  case pen, vial, tablet, capsule, nasal, topical, other

  var id: String { rawValue }

  var title: String {
    switch self {
    case .pen: "Pen"
    case .vial: "Vial"
    case .tablet: "Tablet"
    case .capsule: "Capsule"
    case .nasal: "Nasal spray"
    case .topical: "Topical"
    case .other: "Other"
    }
  }

  var symbol: String {
    switch self {
    case .pen: "syringe"
    case .vial: "cross.vial"
    case .tablet, .capsule: "pills"
    case .nasal: "nose"
    case .topical: "hand.raised"
    case .other: "circle.dashed"
    }
  }
}

/// The repeat patterns the editor offers. StackCore supports more; these cover the
/// common cases without a long form.
enum StackRepeat: String, CaseIterable, Identifiable, Codable {
  case daily, everyNDays, weekly, weekdays, asNeeded

  var id: String { rawValue }

  var title: String {
    switch self {
    case .daily: "Every day"
    case .everyNDays: "Every few days"
    case .weekly: "Every week"
    case .weekdays: "On chosen days"
    case .asNeeded: "As needed"
    }
  }
}

/// One thing the person takes, with their own schedule and supply. Every value is entered
/// by the person; nothing here is a recommendation. Stored only in the separate Stack
/// store (D04).
@Model
final class StackCompound {
  var name: String
  var formRaw: String
  var unitRaw: String
  /// The person's own planned amount, as a decimal string so it round-trips exactly.
  var amountText: String
  var repeatRaw: String
  var intervalDays: Int
  /// ISO weekdays, 1 = Monday ... 7 = Sunday.
  var weekdays: [Int]
  /// Minutes after midnight.
  var timeMinutes: Int
  var startDate: Date
  var isPaused: Bool
  /// Only a positive half-life with a stated source enables the illustrative curve.
  var halfLifeHours: Double?
  var halfLifeSource: String
  /// Doses in the current pen, vial or pack; 0 means supply is not tracked.
  var supplyDoses: Int
  var supplyStartedAt: Date?
  var notes: String
  var createdAt: Date
  @Relationship(deleteRule: .cascade, inverse: \StackDose.compound)
  var doses: [StackDose] = []

  init(
    name: String, form: StackForm, unit: StackUnit, amountText: String,
    repeatPattern: StackRepeat, intervalDays: Int = 1, weekdays: [Int] = [],
    timeMinutes: Int, startDate: Date, halfLifeHours: Double? = nil, halfLifeSource: String = "",
    supplyDoses: Int = 0, supplyStartedAt: Date? = nil, notes: String = "", createdAt: Date = .now
  ) {
    self.name = name
    self.formRaw = form.rawValue
    self.unitRaw = unit.rawValue
    self.amountText = amountText
    self.repeatRaw = repeatPattern.rawValue
    self.intervalDays = intervalDays
    self.weekdays = weekdays
    self.timeMinutes = timeMinutes
    self.startDate = startDate
    self.isPaused = false
    self.halfLifeHours = halfLifeHours
    self.halfLifeSource = halfLifeSource
    self.supplyDoses = supplyDoses
    self.supplyStartedAt = supplyStartedAt
    self.notes = notes
    self.createdAt = createdAt
  }

  var form: StackForm { StackForm(rawValue: formRaw) ?? .other }
  var unit: StackUnit { StackUnit(rawValue: unitRaw) ?? .mg }
  var repeatPattern: StackRepeat { StackRepeat(rawValue: repeatRaw) ?? .daily }
  var amount: Decimal? { Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")) }
}

/// One logged or skipped dose. The name, amount and unit are copied at logging time so the
/// history stays true if the compound is edited later.
@Model
final class StackDose {
  var compound: StackCompound?
  var compoundName: String
  var amountText: String
  var unitRaw: String
  /// When the dose was taken; nil for a skipped dose.
  var takenAt: Date?
  /// The scheduled time this entry answers, if any.
  var scheduledFor: Date?
  var site: String
  var notes: String
  var createdAt: Date
  var editedAt: Date?

  init(
    compound: StackCompound, amountText: String, takenAt: Date?, scheduledFor: Date?,
    site: String = "", notes: String = "", createdAt: Date = .now
  ) {
    self.compound = compound
    self.compoundName = compound.name
    self.amountText = amountText
    self.unitRaw = compound.unitRaw
    self.takenAt = takenAt
    self.scheduledFor = scheduledFor
    self.site = site
    self.notes = notes
    self.createdAt = createdAt
  }

  var isSkipped: Bool { takenAt == nil }
  var unit: StackUnit { StackUnit(rawValue: unitRaw) ?? .mg }
  var amount: Decimal? { Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")) }
}
