import CaliberCore
import Foundation
import SwiftData

/// Storage adapter only. A screen can render `state.remaining(at:)` and schedule
/// an OS notification for `state.deadline`; this adapter requests no permissions.
@MainActor
enum TrainingWorkoutRestTimer {
  static func state(for workout: TrainingWorkout) throws -> WorkoutRestTimer? {
    guard let data = workout.restTimerStateData else { return nil }
    let state = try JSONDecoder().decode(WorkoutRestTimer.self, from: data)
    guard state.workoutID == workout.id,
      workout.completedSets.contains(where: { $0.id == state.setID })
    else { throw WorkoutRestTimerError.invalidState }
    return state
  }

  static func adjust(
    _ workout: TrainingWorkout, by seconds: TimeInterval = 15, in context: ModelContext
  ) throws {
    guard workout.isActive, var timer = try state(for: workout) else {
      throw TrainingWorkoutError.invalidOperation
    }
    try timer.adjust(by: seconds)
    workout.restTimerStateData = try JSONEncoder().encode(timer)
    try TrainingWorkoutLogger.save(context)
  }

  static func skip(
    _ workout: TrainingWorkout, at date: Date = .now, in context: ModelContext
  ) throws {
    guard workout.isActive, var timer = try state(for: workout) else {
      throw TrainingWorkoutError.invalidOperation
    }
    try timer.end(at: date, reason: .skipped)
    workout.restTimerStateData = try JSONEncoder().encode(timer)
    try TrainingWorkoutLogger.save(context)
  }

  /// Call when the next set STARTS, not when it is completed. An overdue target
  /// can still record the longer actual rest. Skip never fabricates an interval.
  static func beginNextSet(
    _ workout: TrainingWorkout, at date: Date = .now, in context: ModelContext
  ) throws {
    guard workout.isActive, var timer = try state(for: workout),
      let set = workout.completedSets.first(where: { $0.id == timer.setID })
    else { throw TrainingWorkoutError.invalidOperation }
    try timer.end(at: date, reason: .nextSetStarted)
    let data = try JSONEncoder().encode(timer)
    set.actualRestSeconds = timer.actualRestSeconds
    workout.restTimerStateData = data
    try TrainingWorkoutLogger.save(context)
  }

  static func clearIfOwned(by set: TrainingWorkoutSet, in workout: TrainingWorkout) throws {
    if try state(for: workout)?.setID == set.id { workout.restTimerStateData = nil }
  }
}
