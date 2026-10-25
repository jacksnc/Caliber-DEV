import Foundation
import SwiftData

@Model
final class TrainingWorkout {
  var id: UUID
  var name: String
  var startedAt: Date
  var completedAt: Date?
  var notes: String

  @Relationship(deleteRule: .cascade, inverse: \TrainingWorkoutExercise.workout)
  var exercises: [TrainingWorkoutExercise] = []

  init(name: String = "Workout", startedAt: Date = .now, notes: String = "") {
    id = UUID()
    self.name = name
    self.startedAt = startedAt
    self.notes = notes
  }

  var isActive: Bool { completedAt == nil }

  var sortedExercises: [TrainingWorkoutExercise] {
    exercises.sorted {
      if $0.position == $1.position { return $0.id.uuidString < $1.id.uuidString }
      return $0.position < $1.position
    }
  }

  var completedSets: [TrainingWorkoutSet] {
    exercises.flatMap(\.sets).filter { $0.completedAt != nil }
  }

  var volumeKilograms: Double {
    completedSets.reduce(0) { $0 + $1.countedVolumeKilograms }
  }
}

@Model
final class TrainingWorkoutExercise {
  var id: UUID
  var position: Int
  var notes: String
  var workout: TrainingWorkout?
  var exercise: TrainingExercise?

  @Relationship(deleteRule: .cascade, inverse: \TrainingWorkoutSet.workoutExercise)
  var sets: [TrainingWorkoutSet] = []

  init(position: Int, exercise: TrainingExercise, notes: String = "") {
    id = UUID()
    self.position = position
    self.exercise = exercise
    self.notes = notes
  }

  var sortedSets: [TrainingWorkoutSet] {
    sets.sorted {
      if $0.position == $1.position { return $0.id.uuidString < $1.id.uuidString }
      return $0.position < $1.position
    }
  }
}

@Model
final class TrainingWorkoutSet {
  var id: UUID
  var position: Int
  var enteredWeight: Double
  var enteredWeightUnitRawValue: String
  var weightKilograms: Double
  var repetitions: Int
  var rpe: Double?
  var isWarmup: Bool
  var completedAt: Date?
  var workoutExercise: TrainingWorkoutExercise?

  init(position: Int, isWarmup: Bool = false) {
    id = UUID()
    self.position = position
    enteredWeight = 0
    enteredWeightUnitRawValue = "lb"
    weightKilograms = 0
    repetitions = 0
    self.isWarmup = isWarmup
  }

  var countedVolumeKilograms: Double {
    guard completedAt != nil, !isWarmup else { return 0 }
    return weightKilograms * Double(repetitions)
  }
}
