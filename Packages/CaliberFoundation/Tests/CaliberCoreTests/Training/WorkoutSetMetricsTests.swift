import Foundation
import XCTest

@testable import CaliberCore

final class WorkoutSetMetricsTests: XCTestCase {
  private let locale = Locale(identifier: "en_US")

  func testAllNineMetricsUseOnlyTheirRequiredDimensions() throws {
    var draft = WorkoutSetDraft()
    draft.weight = "20"
    draft.massUnit = .kilograms
    draft.repetitions = "5"
    draft.durationSeconds = "30.5"
    draft.distance = "1.5"
    draft.distanceUnit = .kilometers
    let body = try WorkoutBodyweight(kilograms: 80, recordedAt: .distantPast)
    let volumes: [WorkoutMetric: Double] = [
      .weightAndReps: 100, .bodyweightAndReps: 400,
      .weightedBodyweight: 500, .assistedBodyweight: 300,
    ]
    for metric in WorkoutMetric.allCases {
      let result = try draft.validated(for: metric, bodyweight: body, locale: locale)
      XCTAssertEqual(result.volumeKilograms, volumes[metric], metric.rawValue)
      XCTAssertEqual(result.repetitions, metric.usesRepetitions ? 5 : nil)
      XCTAssertEqual(result.durationSeconds, metric.usesDuration ? 30.5 : nil)
      XCTAssertEqual(result.distanceMeters, metric.usesDistance ? 1_500 : nil)
      XCTAssertEqual(result.enteredWeight, metric.usesWeight ? 20 : nil)
      XCTAssertEqual(result.bodyweight, metric.usesBodyweight ? body : nil)
    }
  }

  func testExactEnteredValuesAndDistanceFactors() throws {
    var draft = WorkoutSetDraft()
    draft.weight = "135"
    draft.repetitions = "8"
    let pounds = try draft.validated(for: .weightAndReps, locale: locale)
    XCTAssertEqual(pounds.enteredWeight, 135)
    XCTAssertEqual(try XCTUnwrap(pounds.weightKilograms), 61.23496995, accuracy: 1e-10)
    for (unit, meters) in [(WorkoutDistanceUnit.miles, 1_609.344), (.yards, 0.9144), (.meters, 1)] {
      draft.distance = "1"
      draft.distanceUnit = unit
      XCTAssertEqual(try draft.validated(for: .distance).distanceMeters, meters)
    }
    draft.weight = "2,5"
    draft.massUnit = .kilograms
    XCTAssertEqual(
      try draft.validated(for: .weightAndReps, locale: Locale(identifier: "de_DE")).enteredWeight,
      2.5)
    XCTAssertThrowsError(try draft.validated(for: .weightAndReps, locale: locale))
  }

  func testMissingAndExcessiveBodyweightInputs() throws {
    var draft = WorkoutSetDraft()
    draft.weight = "81"
    draft.massUnit = .kilograms
    draft.repetitions = "5"
    XCTAssertThrowsError(try draft.validated(for: .bodyweightAndReps)) {
      XCTAssertEqual($0 as? WorkoutSetValidationError, .missingBodyweight)
    }
    let body = try WorkoutBodyweight(kilograms: 80, recordedAt: .distantPast)
    XCTAssertThrowsError(try draft.validated(for: .assistedBodyweight, bodyweight: body)) {
      XCTAssertEqual($0 as? WorkoutSetValidationError, .excessiveAssistance)
    }
    draft.weight = "80"
    XCTAssertEqual(
      try draft.validated(for: .assistedBodyweight, bodyweight: body).volumeKilograms, 0)
    for weight in [0, -1, Double.infinity, .nan] {
      XCTAssertThrowsError(try WorkoutBodyweight(kilograms: weight, recordedAt: .now))
    }
  }

  func testInvalidNumbersAndOverflowCannotBecomeLoggedValues() throws {
    for bad in ["", "-1", "nan", "inf", "1e10", "1,000", "1.2.3"] {
      var draft = WorkoutSetDraft()
      draft.weight = bad
      draft.repetitions = bad
      draft.durationSeconds = bad
      draft.distance = bad
      XCTAssertThrowsError(try draft.validated(for: .weightAndReps, locale: locale))
      XCTAssertThrowsError(try draft.validated(for: .duration, locale: locale))
      XCTAssertThrowsError(try draft.validated(for: .distance, locale: locale))
    }
    var draft = WorkoutSetDraft()
    draft.weight = "0"
    for reps in ["0", "5.5", "+5", "-1", String(repeating: "9", count: 30)] {
      draft.repetitions = reps
      XCTAssertThrowsError(try draft.validated(for: .weightAndReps))
    }
    draft.repetitions = "5"
    XCTAssertEqual(try draft.validated(for: .weightAndReps).volumeKilograms, 0)
    draft.durationSeconds = "0"
    draft.distance = "0"
    XCTAssertThrowsError(try draft.validated(for: .duration))
    XCTAssertThrowsError(try draft.validated(for: .distance))
    draft.weight = "1" + String(repeating: "0", count: 308)
    XCTAssertThrowsError(try draft.validated(for: .weightAndReps)) {
      XCTAssertEqual($0 as? WorkoutSetValidationError, .overflow)
    }
  }

  func testEffortIsOptionalAndUsesExactlyOneScale() throws {
    var draft = WorkoutSetDraft()
    draft.repetitions = "5"
    XCTAssertTrue(try draft.validated(for: .repsOnly).countsAsHardSet)
    draft.effort = "8.5"
    let rpe = try draft.validated(for: .repsOnly)
    XCTAssertEqual(rpe.rpe, 8.5)
    XCTAssertNil(rpe.rir)
    XCTAssertTrue(rpe.countsAsHardSet)
    draft.effort = "0"
    XCTAssertFalse(try draft.validated(for: .repsOnly).countsAsHardSet)
    draft.effort = "10.5"
    XCTAssertThrowsError(try draft.validated(for: .repsOnly))
    draft.effortScale = .rir
    let rir = try draft.validated(for: .repsOnly)
    XCTAssertEqual(rir.rir, 10.5)
    XCTAssertNil(rir.rpe)
    XCTAssertFalse(rir.countsAsHardSet)
    draft.effort = "4"
    XCTAssertTrue(try draft.validated(for: .repsOnly).countsAsHardSet)
    draft.effort = "-1"
    XCTAssertThrowsError(try draft.validated(for: .repsOnly))
  }

  func testKindsAndOverridesKeepWarmupsOutOfRecords() throws {
    var draft = WorkoutSetDraft()
    draft.weight = "100"
    draft.massUnit = .kilograms
    draft.repetitions = "5"
    draft.customKindName = "  Technique  "
    for kind in WorkoutSetKind.allCases {
      draft.kind = kind
      let set = try draft.validated(for: .weightAndReps)
      XCTAssertEqual(set.volumeKilograms, kind == .warmup ? 0 : 500)
      XCTAssertEqual(set.counting.records, kind != .warmup)
      XCTAssertEqual(set.countsAsHardSet, kind != .warmup)
      XCTAssertEqual(set.customKindName, kind == .custom ? "Technique" : nil)
    }
    draft.kind = .warmup
    draft.counting = WorkoutSetCounting(kind: .working)
    let warmup = try draft.validated(for: .weightAndReps)
    XCTAssertEqual(warmup.volumeKilograms, 500)
    XCTAssertFalse(warmup.counting.records)
    draft.kind = .custom
    draft.customKindName = " "
    XCTAssertThrowsError(try draft.validated(for: .weightAndReps))
  }
}
