import CaliberCore
import Foundation
import SwiftData

@Model
final class TrainingWorkout {
  var id: UUID
  var name: String
  var startedAt: Date
  var completedAt: Date?
  var notes: String
  var gymID: UUID? = nil
  var restTimerStateData: Data? = nil

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
  var metricTypeSnapshotRawValue: String? = nil

  @Relationship(deleteRule: .cascade, inverse: \TrainingWorkoutSet.workoutExercise)
  var sets: [TrainingWorkoutSet] = []

  init(position: Int, exercise: TrainingExercise, notes: String = "") {
    id = UUID()
    self.position = position
    self.exercise = exercise
    metricTypeSnapshotRawValue = exercise.metricTypeRawValue
    self.notes = notes
  }

  var metric: WorkoutMetric {
    WorkoutMetric(rawValue: metricTypeSnapshotRawValue ?? "")
      ?? exercise?.metricType.coreMetric ?? .weightAndReps
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

  // Optional additive columns preserve the existing store and its completed sets.
  var metricTypeSnapshotRawValue: String? = nil
  var durationSeconds: Double? = nil
  var enteredDistance: Double? = nil
  var enteredDistanceUnitRawValue: String? = nil
  var distanceMeters: Double? = nil
  var bodyweightKilograms: Double? = nil
  var bodyweightEntryID: UUID? = nil
  var bodyweightRecordedAt: Date? = nil
  var rir: Double? = nil
  var setKindRawValue: String? = nil
  var customSetKindName: String? = nil
  var countsTowardVolume: Bool? = nil
  var countsTowardHardSets: Bool? = nil
  var countsTowardRecords: Bool? = nil
  var sideRawValue: String? = nil
  var plannedRestSeconds: Double? = nil
  var actualRestSeconds: Double? = nil

  init(position: Int, isWarmup: Bool = false) {
    id = UUID()
    self.position = position
    enteredWeight = 0
    enteredWeightUnitRawValue = "lb"
    weightKilograms = 0
    repetitions = 0
    self.isWarmup = isWarmup
  }

  var kind: WorkoutSetKind {
    get {
      // The existing screen still writes isWarmup. Honor it until the UI adopts
      // the full kind picker, then use the saved kind for the other ten types.
      if isWarmup { return .warmup }
      let stored = WorkoutSetKind(rawValue: setKindRawValue ?? "") ?? .working
      return stored == .warmup ? .working : stored
    }
    set {
      setKindRawValue = newValue.rawValue
      isWarmup = newValue == .warmup
    }
  }

  var counting: WorkoutSetCounting {
    // A legacy warm-up toggle changes the type without going through `kind`.
    // Defaults must change with it rather than keeping the old type's defaults.
    let matchesStoredKind = setKindRawValue == kind.rawValue
    return WorkoutSetCounting(
      kind: kind, volume: matchesStoredKind ? countsTowardVolume : nil,
      hardSets: matchesStoredKind ? countsTowardHardSets : nil,
      records: matchesStoredKind ? countsTowardRecords : nil)
  }

  var countedVolumeKilograms: Double {
    guard completedAt != nil, counting.volume else { return 0 }
    // Every legacy set was entered through weight × reps, even if its exercise
    // had another metric. Never reinterpret historical rows during a read.
    let metric = WorkoutMetric(rawValue: metricTypeSnapshotRawValue ?? "") ?? .weightAndReps
    let load: Double
    switch metric {
    case .weightAndReps: load = weightKilograms
    case .bodyweightAndReps:
      guard let bodyweightKilograms else { return 0 }
      load = bodyweightKilograms
    case .weightedBodyweight:
      guard let bodyweightKilograms else { return 0 }
      load = bodyweightKilograms + weightKilograms
    case .assistedBodyweight:
      guard let bodyweightKilograms else { return 0 }
      load = bodyweightKilograms - weightKilograms
    default: return 0
    }
    let volume = load * Double(repetitions)
    return load >= 0 && repetitions > 0 && volume.isFinite ? volume : 0
  }
}
