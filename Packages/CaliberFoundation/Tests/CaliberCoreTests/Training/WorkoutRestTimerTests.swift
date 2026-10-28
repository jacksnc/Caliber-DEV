import Foundation
import XCTest

@testable import CaliberCore

final class WorkoutRestTimerTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 1_700_000_000)

  private func timer(seconds: Double = 90) throws -> WorkoutRestTimer {
    try WorkoutRestTimer(
      workoutID: UUID(), setID: UUID(), startedAt: start, durationSeconds: seconds)
  }

  func testRestoredDeadlineSurvivesElapsedBackgroundTime() throws {
    let original = try timer()
    let data = try JSONEncoder().encode(original)
    let restored = try JSONDecoder().decode(WorkoutRestTimer.self, from: data)
    XCTAssertEqual(restored, original)
    XCTAssertEqual(restored.remaining(at: start.addingTimeInterval(40)), 50)
    XCTAssertEqual(restored.remaining(at: start.addingTimeInterval(110)), 0)
    XCTAssertNil(restored.actualRestSeconds)
  }

  func testAdjustAndOverdueActualRest() throws {
    var rest = try timer()
    try rest.adjust(by: 15)
    XCTAssertEqual(rest.remaining(at: start), 105)
    try rest.adjust(by: -15)
    XCTAssertEqual(rest.remaining(at: start), 90)
    try rest.end(at: start.addingTimeInterval(120), reason: .nextSetStarted)
    XCTAssertEqual(rest.actualRestSeconds, 120)
    XCTAssertEqual(rest.remaining(at: start.addingTimeInterval(50)), 0)
    XCTAssertThrowsError(try rest.adjust(by: 15))
    XCTAssertThrowsError(try rest.end(at: start.addingTimeInterval(125), reason: .skipped))
    XCTAssertEqual(
      try JSONDecoder().decode(WorkoutRestTimer.self, from: JSONEncoder().encode(rest)), rest)
  }

  func testSkipDoesNotInventActualRest() throws {
    var rest = try timer()
    try rest.end(at: start.addingTimeInterval(10), reason: .skipped)
    XCTAssertNil(rest.actualRestSeconds)
  }

  func testInvalidDatesDurationsAndSerializedStateAreRejected() throws {
    for seconds in [0, -1, 86_401, Double.infinity, .nan] {
      XCTAssertThrowsError(try timer(seconds: seconds))
    }
    XCTAssertThrowsError(
      try WorkoutRestTimer(
        workoutID: UUID(), setID: UUID(), startedAt: Date(timeIntervalSince1970: .infinity),
        durationSeconds: 90))
    var rest = try timer()
    XCTAssertThrowsError(try rest.end(at: start.addingTimeInterval(-1), reason: .nextSetStarted))
    XCTAssertThrowsError(try rest.adjust(by: -.infinity))
    XCTAssertThrowsError(try rest.adjust(by: -91))
    let encoded = try JSONEncoder().encode(rest)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object["version"] = 2
    XCTAssertThrowsError(
      try JSONDecoder().decode(
        WorkoutRestTimer.self, from: JSONSerialization.data(withJSONObject: object)))
    object["version"] = 1
    object["deadline"] = start.timeIntervalSinceReferenceDate - 1
    XCTAssertThrowsError(
      try JSONDecoder().decode(
        WorkoutRestTimer.self, from: JSONSerialization.data(withJSONObject: object)))
    object["deadline"] = start.timeIntervalSinceReferenceDate + 90
    object["endReason"] = "skipped"
    XCTAssertThrowsError(
      try JSONDecoder().decode(
        WorkoutRestTimer.self, from: JSONSerialization.data(withJSONObject: object)))
  }
}
