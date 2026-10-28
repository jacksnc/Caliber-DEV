import Foundation

/// The measurements an exercise actually uses. Distance is deliberately separate
/// from the profile's height unit; a run is never stored as inches or centimeters.
public enum WorkoutMetric: String, Codable, CaseIterable, Sendable {
  case weightAndReps, bodyweightAndReps, weightedBodyweight, assistedBodyweight
  case repsOnly, duration, weightAndDuration, distance, distanceAndDuration

  public var usesWeight: Bool {
    [.weightAndReps, .weightedBodyweight, .assistedBodyweight, .weightAndDuration].contains(self)
  }
  public var usesRepetitions: Bool {
    [.weightAndReps, .bodyweightAndReps, .weightedBodyweight, .assistedBodyweight, .repsOnly]
      .contains(self)
  }
  public var usesBodyweight: Bool {
    [.bodyweightAndReps, .weightedBodyweight, .assistedBodyweight].contains(self)
  }
  public var usesDuration: Bool {
    [.duration, .weightAndDuration, .distanceAndDuration].contains(self)
  }
  public var usesDistance: Bool { self == .distance || self == .distanceAndDuration }
}

public enum WorkoutDistanceUnit: String, Codable, CaseIterable, Sendable {
  case meters = "m"
  case kilometers = "km"
  case miles = "mi"
  case yards = "yd"
  public var metersPerUnit: Double {
    switch self {
    case .meters: 1
    case .kilometers: 1_000
    case .miles: 1_609.344
    case .yards: 0.9144
    }
  }
}

public enum WorkoutSetKind: String, Codable, CaseIterable, Sendable {
  case warmup, working, topSet, backoff, drop, failure, amrap, cluster, restPause, myoRep, custom
}

public enum WorkoutSetSide: String, Codable, CaseIterable, Sendable { case both, left, right }
public enum WorkoutEffortScale: String, Codable, Sendable { case rpe, rir }

public enum WorkoutSetValidationError: Error, Equatable {
  case invalidWeight, invalidRepetitions, invalidDuration, invalidDistance, invalidEffort
  case missingBodyweight, invalidBodyweight, excessiveAssistance, invalidCustomKind, overflow
}

/// User choices apply independently to volume, hard sets and records. Warm-ups
/// never earn records, including when an imported override asks for them.
public struct WorkoutSetCounting: Codable, Equatable, Sendable {
  public var volume: Bool
  public var hardSets: Bool
  public var records: Bool

  public init(
    kind: WorkoutSetKind, volume: Bool? = nil, hardSets: Bool? = nil, records: Bool? = nil
  ) {
    self.volume = volume ?? (kind != .warmup)
    self.hardSets = hardSets ?? (kind != .warmup)
    self.records = kind != .warmup && (records ?? true)
  }
}

/// A captured reading, not a live link that changes old workout totals.
public struct WorkoutBodyweight: Equatable, Sendable {
  public let kilograms: Double
  public let sourceID: UUID?
  public let recordedAt: Date

  public init(kilograms: Double, sourceID: UUID? = nil, recordedAt: Date) throws {
    guard kilograms.isFinite, kilograms > 0, recordedAt.timeIntervalSince1970.isFinite else {
      throw WorkoutSetValidationError.invalidBodyweight
    }
    self.kilograms = kilograms
    self.sourceID = sourceID
    self.recordedAt = recordedAt
  }
}

/// Seconds are entered as seconds (including fractional seconds), not ambiguous
/// clock strings. Only fields required by the chosen metric are parsed.
public struct WorkoutSetDraft: Sendable {
  public var weight = ""
  public var repetitions = ""
  public var durationSeconds = ""
  public var distance = ""
  public var effort = ""
  public var effortScale: WorkoutEffortScale = .rpe
  public var massUnit: MassUnit = .pounds
  public var distanceUnit: WorkoutDistanceUnit = .meters
  public var side: WorkoutSetSide = .both
  public var kind: WorkoutSetKind = .working
  public var customKindName: String?
  public var counting: WorkoutSetCounting?

  public init() {}

  public func validated(
    for metric: WorkoutMetric, bodyweight: WorkoutBodyweight? = nil, locale: Locale = .current
  ) throws -> WorkoutSetValues {
    let enteredWeight =
      try metric.usesWeight
      ? number(weight, positive: false, locale: locale, error: .invalidWeight) : nil
    let kilograms = enteredWeight.map { massUnit.kilograms(from: $0) }
    let reps: Int?
    if metric.usesRepetitions {
      let text = repetitions.trimmingCharacters(in: .whitespacesAndNewlines)
      guard text.range(of: "^[0-9]+$", options: .regularExpression) != nil,
        let value = Int(text), value > 0
      else { throw WorkoutSetValidationError.invalidRepetitions }
      reps = value
    } else {
      reps = nil
    }
    let seconds =
      try metric.usesDuration
      ? number(durationSeconds, positive: true, locale: locale, error: .invalidDuration) : nil
    let enteredDistance =
      try metric.usesDistance
      ? number(distance, positive: true, locale: locale, error: .invalidDistance) : nil
    let meters = enteredDistance.map { $0 * distanceUnit.metersPerUnit }
    if metric.usesBodyweight, bodyweight == nil {
      throw WorkoutSetValidationError.missingBodyweight
    }
    if metric == .assistedBodyweight, let kilograms, let bodyweight,
      kilograms > bodyweight.kilograms
    {
      throw WorkoutSetValidationError.excessiveAssistance
    }

    let trimmedEffort = effort.trimmingCharacters(in: .whitespacesAndNewlines)
    let effortValue =
      try trimmedEffort.isEmpty
      ? nil : number(trimmedEffort, positive: false, locale: locale, error: .invalidEffort)
    if let effortValue, effortScale == .rpe, effortValue > 10 {
      throw WorkoutSetValidationError.invalidEffort
    }
    let label = customKindName?.trimmingCharacters(in: .whitespacesAndNewlines)
    if kind == .custom, label?.isEmpty != false {
      throw WorkoutSetValidationError.invalidCustomKind
    }
    let counts = counting ?? WorkoutSetCounting(kind: kind)
    let result = WorkoutSetValues(
      metric: metric, enteredWeight: enteredWeight, massUnit: massUnit,
      weightKilograms: kilograms, repetitions: reps, durationSeconds: seconds,
      enteredDistance: enteredDistance, distanceUnit: distanceUnit, distanceMeters: meters,
      bodyweight: metric.usesBodyweight ? bodyweight : nil,
      rpe: effortScale == .rpe ? effortValue : nil,
      rir: effortScale == .rir ? effortValue : nil, side: side, kind: kind,
      customKindName: kind == .custom ? label : nil,
      counting: WorkoutSetCounting(
        kind: kind, volume: counts.volume, hardSets: counts.hardSets, records: counts.records))
    guard
      [kilograms, meters, result.effectiveLoadKilograms, result.volumeKilograms]
        .compactMap({ $0 }).allSatisfy({ $0.isFinite })
    else { throw WorkoutSetValidationError.overflow }
    return result
  }

  private func number(
    _ text: String, positive: Bool, locale: Locale, error validationError: WorkoutSetValidationError
  ) throws -> Double {
    do {
      let value = try QuantityParsing.nonnegative(text, locale: locale)
      guard !positive || value > 0 else { throw validationError }
      return value
    } catch { throw validationError }
  }
}

public struct WorkoutSetValues: Equatable, Sendable {
  public let metric: WorkoutMetric
  public let enteredWeight: Double?
  public let massUnit: MassUnit
  public let weightKilograms: Double?
  public let repetitions: Int?
  public let durationSeconds: Double?
  public let enteredDistance: Double?
  public let distanceUnit: WorkoutDistanceUnit
  public let distanceMeters: Double?
  public let bodyweight: WorkoutBodyweight?
  public let rpe: Double?
  public let rir: Double?
  public let side: WorkoutSetSide
  public let kind: WorkoutSetKind
  public let customKindName: String?
  public let counting: WorkoutSetCounting

  public var effectiveLoadKilograms: Double? {
    switch metric {
    case .weightAndReps, .weightAndDuration: weightKilograms
    case .bodyweightAndReps: bodyweight?.kilograms
    case .weightedBodyweight: bodyweight.map { $0.kilograms + (weightKilograms ?? 0) }
    case .assistedBodyweight: bodyweight.map { $0.kilograms - (weightKilograms ?? 0) }
    default: nil
    }
  }

  /// Weight × seconds is not rep tonnage. Missing load is not a zero load.
  public var volumeKilograms: Double? {
    guard metric.usesRepetitions, let load = effectiveLoadKilograms, let repetitions else {
      return nil
    }
    return counting.volume ? load * Double(repetitions) : 0
  }

  public var countsAsHardSet: Bool {
    guard counting.hardSets else { return false }
    let reserve = rir ?? rpe.map { 10 - $0 }
    return reserve.map { $0 <= 4 } ?? true
  }
}
