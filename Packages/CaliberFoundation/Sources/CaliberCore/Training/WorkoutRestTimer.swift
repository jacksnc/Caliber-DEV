import Foundation

public enum WorkoutRestTimerError: Error, Equatable {
  case invalidDuration, invalidDate, alreadyEnded, invalidState
}

/// A durable deadline. No background polling or repeating decrement is needed;
/// callers render remaining(at:) after foregrounding or restoring this value.
public struct WorkoutRestTimer: Codable, Equatable, Sendable {
  public enum EndReason: String, Codable, Sendable {
    case nextSetStarted, skipped, workoutFinished, superseded, undone, deleted
  }
  public let version = 1
  public let workoutID: UUID
  public let setID: UUID
  public let startedAt: Date
  public private(set) var deadline: Date
  public private(set) var endedAt: Date?
  public private(set) var endReason: EndReason?

  public init(workoutID: UUID, setID: UUID, startedAt: Date, durationSeconds: Double) throws {
    guard durationSeconds.isFinite, durationSeconds > 0, durationSeconds <= 86_400 else {
      throw WorkoutRestTimerError.invalidDuration
    }
    guard startedAt.timeIntervalSince1970.isFinite else {
      throw WorkoutRestTimerError.invalidDate
    }
    self.workoutID = workoutID
    self.setID = setID
    self.startedAt = startedAt
    deadline = startedAt.addingTimeInterval(durationSeconds)
  }

  public func remaining(at date: Date) -> TimeInterval {
    guard endedAt == nil, date.timeIntervalSince1970.isFinite else { return 0 }
    return max(0, deadline.timeIntervalSince(date))
  }

  public mutating func adjust(by seconds: TimeInterval) throws {
    guard endedAt == nil else { throw WorkoutRestTimerError.alreadyEnded }
    let duration = deadline.timeIntervalSince(startedAt) + seconds
    guard seconds.isFinite, duration.isFinite, (0...86_400).contains(duration) else {
      throw WorkoutRestTimerError.invalidDuration
    }
    deadline = startedAt.addingTimeInterval(duration)
  }

  public mutating func end(at date: Date, reason: EndReason) throws {
    guard endedAt == nil else { throw WorkoutRestTimerError.alreadyEnded }
    guard date.timeIntervalSince1970.isFinite, date >= startedAt,
      date.timeIntervalSince(startedAt).isFinite
    else {
      throw WorkoutRestTimerError.invalidDate
    }
    endedAt = date
    endReason = reason
  }

  /// Completion-to-completion time includes the next exercise's working time.
  /// Actual rest is known only when the person explicitly starts the next set.
  public var actualRestSeconds: TimeInterval? {
    guard endReason == .nextSetStarted, let endedAt else { return nil }
    return endedAt.timeIntervalSince(startedAt)
  }

  private enum CodingKeys: CodingKey {
    case version, workoutID, setID, startedAt, deadline, endedAt, endReason
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    guard try values.decode(Int.self, forKey: .version) == 1 else {
      throw WorkoutRestTimerError.invalidState
    }
    workoutID = try values.decode(UUID.self, forKey: .workoutID)
    setID = try values.decode(UUID.self, forKey: .setID)
    startedAt = try values.decode(Date.self, forKey: .startedAt)
    deadline = try values.decode(Date.self, forKey: .deadline)
    endedAt = try values.decodeIfPresent(Date.self, forKey: .endedAt)
    endReason = try values.decodeIfPresent(EndReason.self, forKey: .endReason)
    let duration = deadline.timeIntervalSince(startedAt)
    guard startedAt.timeIntervalSince1970.isFinite, duration.isFinite,
      (0...86_400).contains(duration), (endedAt == nil) == (endReason == nil),
      endedAt.map({
        $0.timeIntervalSince1970.isFinite && $0 >= startedAt
          && $0.timeIntervalSince(startedAt).isFinite
      }) ?? true
    else { throw WorkoutRestTimerError.invalidState }
  }
}
