import CaliberCore
import Foundation
import SwiftData

@MainActor
enum TrainingWorkoutHistory {
  /// Most recently FINISHED earlier workout at the same gym (nil is its own
  /// scope). Future, active, other-gym and incompatible-metric rows are excluded.
  /// Returning saved sets lets the caller copy by ID without parsing display text.
  static func previousSets(
    for row: TrainingWorkoutExercise, in context: ModelContext
  ) throws -> [TrainingWorkoutSet] {
    guard let current = row.workout, let exerciseID = row.exercise?.id else { return [] }
    let earlier = try context.fetch(FetchDescriptor<TrainingWorkout>())
      .filter {
        $0.id != current.id && $0.gymID == current.gymID
          && $0.completedAt.map { $0 <= current.startedAt } == true
      }
      .sorted {
        if $0.completedAt == $1.completedAt { return $0.id.uuidString > $1.id.uuidString }
        return $0.completedAt! > $1.completedAt!
      }
    for workout in earlier {
      let sets = workout.sortedExercises
        .filter { $0.exercise?.id == exerciseID }
        .flatMap(\.sortedSets)
        .filter {
          guard $0.completedAt != nil else { return false }
          let metric =
            WorkoutMetric(rawValue: $0.metricTypeSnapshotRawValue ?? "") ?? .weightAndReps
          return metric == row.metric
        }
      if !sets.isEmpty { return sets }
    }
    return []
  }

  static func copyPrevious(
    to target: TrainingWorkoutSet, in context: ModelContext
  ) throws {
    guard let row = target.workoutExercise,
      let index = row.sortedSets.firstIndex(where: { $0.id == target.id })
    else { throw TrainingWorkoutError.invalidOperation }
    let previous = try previousSets(for: row, in: context)
    guard previous.indices.contains(index) else { throw TrainingWorkoutError.invalidOperation }
    try TrainingWorkoutLogger.copy(previous[index], to: target, in: context)
  }
}
