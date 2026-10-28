import Foundation
import SwiftData
import Testing

@testable import Caliber__DEV_

// Exact pre-engine model shapes from the branch's base commit. A disposable
// store proves additive lightweight migration through supported SwiftData APIs.
private enum WorkoutStoreV1: VersionedSchema {
  static let versionIdentifier = Schema.Version(1, 0, 0)
  static var models: [any PersistentModel.Type] {
    [
      TrainingExercise.self, TrainingWorkout.self, TrainingWorkoutExercise.self,
      TrainingWorkoutSet.self,
    ]
  }
  @Model
  final class TrainingExercise {
    var id: UUID
    var name: String
    var aliases: String
    var metricTypeRawValue: String
    var isCustom: Bool
    var isFavorite: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \TrainingWorkoutExercise.exercise)
    var workoutExercises: [TrainingWorkoutExercise] = []

    init(
      name: String, aliases: String = "", metricType: ExerciseMetricType = .weightAndReps,
      isCustom: Bool = true, isFavorite: Bool = false, createdAt: Date = .now
    ) {
      id = UUID()
      self.name = name
      self.aliases = aliases
      metricTypeRawValue = metricType.rawValue
      self.isCustom = isCustom
      self.isFavorite = isFavorite
      self.createdAt = createdAt
    }

    var metricType: ExerciseMetricType {
      get { ExerciseMetricType(rawValue: metricTypeRawValue) ?? .weightAndReps }
      set { metricTypeRawValue = newValue.rawValue }
    }
  }

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
}

@MainActor
private func seedOldWorkoutStore(at url: URL) throws -> UUID {
  return try autoreleasepool {
    let schema = Schema(WorkoutStoreV1.models)
    let store = try ModelContainer(
      for: schema,
      configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
    let context = ModelContext(store)
    context.autosaveEnabled = false
    let exercise = WorkoutStoreV1.TrainingExercise(name: "Old workout")
    let workout = WorkoutStoreV1.TrainingWorkout(
      startedAt: Date(timeIntervalSince1970: 1_700_000_000))
    let row = WorkoutStoreV1.TrainingWorkoutExercise(position: 0, exercise: exercise)
    let set = WorkoutStoreV1.TrainingWorkoutSet(position: 0)
    context.insert(exercise)
    context.insert(workout)
    context.insert(row)
    context.insert(set)
    row.workout = workout
    workout.exercises.append(row)
    row.sets.append(set)
    set.workoutExercise = row
    set.enteredWeight = 135
    set.enteredWeightUnitRawValue = "lb"
    set.weightKilograms = 61.23496995
    set.repetitions = 8
    set.rpe = 8.5
    set.completedAt = workout.startedAt.addingTimeInterval(10)
    try context.save()
    return workout.id
  }
}

@MainActor @Test
func workoutEngineOpensPreEngineDiskStoreWithoutChangingOldSets() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  // SwiftData may retain migration handles. The OS reclaims this synthetic
  // temporary fixture after the test host exits; do not unlink an open database.
  try autoreleasepool {
    let url = directory.appendingPathComponent("OldWorkout.sqlite")
    let id = try seedOldWorkoutStore(at: url)
    let schema = Schema([
      TrainingExercise.self, TrainingWorkout.self, TrainingWorkoutExercise.self,
      TrainingWorkoutSet.self,
    ])
    let store = try ModelContainer(
      for: schema,
      configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
    let context = ModelContext(store)
    let workout = try #require(context.fetch(FetchDescriptor<TrainingWorkout>()).first)
    let set = try #require(workout.completedSets.first)
    #expect(workout.id == id)
    #expect(workout.isActive)
    #expect(workout.restTimerStateData == nil)
    #expect(set.enteredWeight == 135)
    #expect(set.enteredWeightUnitRawValue == "lb")
    #expect(set.repetitions == 8 && set.rpe == 8.5)
    #expect(set.metricTypeSnapshotRawValue == nil)
    #expect(abs(workout.volumeKilograms - 489.8797596) < 1e-8)
    #expect(
      set.durationSeconds == nil && set.distanceMeters == nil && set.bodyweightKilograms == nil)
    #expect(set.workoutExercise?.exercise?.name == "Old workout")
  }
}
