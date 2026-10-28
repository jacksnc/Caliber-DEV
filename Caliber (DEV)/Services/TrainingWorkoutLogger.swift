import CaliberCore
import Foundation
import SwiftData

enum TrainingWorkoutError: LocalizedError, Equatable {
  case invalidWeight, invalidRepetitions, invalidRPE
  case invalidDuration, invalidDistance, missingBodyweight, excessiveAssistance
  case invalidCustomKind, invalidRestDuration, invalidOperation, metricMismatch, overflow

  var errorDescription: String? {
    switch self {
    case .invalidWeight:
      String(localized: "Enter a weight of zero or greater.", table: "WorkoutEngine")
    case .invalidRepetitions:
      String(
        localized: "Enter a whole number of repetitions greater than zero.", table: "WorkoutEngine")
    case .invalidRPE:
      String(
        localized: "Enter RPE from 0 to 10, nonnegative RIR, or leave effort blank.",
        table: "WorkoutEngine")
    case .invalidDuration:
      String(localized: "Enter a duration in seconds greater than zero.", table: "WorkoutEngine")
    case .invalidDistance:
      String(localized: "Enter a distance greater than zero.", table: "WorkoutEngine")
    case .missingBodyweight:
      String(localized: "Add a body weight before completing this set.", table: "WorkoutEngine")
    case .excessiveAssistance:
      String(
        localized: "Assistance cannot exceed the body weight recorded for this set.",
        table: "WorkoutEngine")
    case .invalidCustomKind:
      String(localized: "Give the custom set type a name.", table: "WorkoutEngine")
    case .invalidRestDuration:
      String(
        localized: "Rest must be greater than zero and no longer than 24 hours.",
        table: "WorkoutEngine")
    case .invalidOperation:
      String(
        localized: "This workout or set cannot be changed by that action.", table: "WorkoutEngine")
    case .metricMismatch:
      String(
        localized: "Choose a previous set with the same exercise measurements.",
        table: "WorkoutEngine")
    case .overflow:
      String(localized: "One of the values is too large to save.", table: "WorkoutEngine")
    }
  }
}

/// Command methods save before returning. Give commands a context without other
/// pending edits: a failed save rolls its transaction back, including inserted rows.
@MainActor
enum TrainingWorkoutLogger {
  static func start(in context: ModelContext, date: Date = .now) throws -> TrainingWorkout {
    let workout = TrainingWorkout(
      name: "Workout · " + date.formatted(date: .abbreviated, time: .omitted), startedAt: date)
    context.insert(workout)
    try save(context)
    return workout
  }

  /// Copies targets, never yesterday's effort, body weight, completion or rest.
  static func repeating(
    _ previous: TrainingWorkout, in context: ModelContext, date: Date = .now
  ) throws -> TrainingWorkout {
    let workout = TrainingWorkout(name: previous.name, startedAt: date)
    workout.gymID = previous.gymID
    context.insert(workout)
    for row in previous.sortedExercises {
      guard let exercise = row.exercise else { continue }
      let copy = TrainingWorkoutExercise(position: workout.exercises.count, exercise: exercise)
      copy.metricTypeSnapshotRawValue = row.metric.rawValue
      context.insert(copy)
      workout.exercises.append(copy)
      copy.workout = workout
      let finished = row.sortedSets.filter { $0.completedAt != nil }
      for index in 0..<max(finished.count, 1) {
        let set = TrainingWorkoutSet(position: index)
        if finished.indices.contains(index) { copyTargets(from: finished[index], to: set) }
        context.insert(set)
        copy.sets.append(set)
        set.workoutExercise = copy
      }
    }
    try save(context)
    return workout
  }

  static func addExercise(
    _ exercise: TrainingExercise, to workout: TrainingWorkout, in context: ModelContext
  ) throws -> TrainingWorkoutExercise {
    guard workout.isActive else { throw TrainingWorkoutError.invalidOperation }
    let row = TrainingWorkoutExercise(
      position: (workout.exercises.map(\.position).max() ?? -1) + 1, exercise: exercise)
    context.insert(row)
    workout.exercises.append(row)
    row.workout = workout
    _ = try addSet(to: row, in: context, save: false)
    try save(context)
    return row
  }

  static func addSet(
    to exercise: TrainingWorkoutExercise, in context: ModelContext, save shouldSave: Bool = true
  ) throws -> TrainingWorkoutSet {
    guard exercise.workout?.isActive == true else { throw TrainingWorkoutError.invalidOperation }
    let set = TrainingWorkoutSet(position: (exercise.sets.map(\.position).max() ?? -1) + 1)
    if let previous = exercise.sortedSets.last { copyTargets(from: previous, to: set) }
    context.insert(set)
    exercise.sets.append(set)
    set.workoutExercise = exercise
    if shouldSave { try save(context) }
    return set
  }

  /// Compatibility entry point for Claude's current weight/reps editor.
  static func complete(
    _ set: TrainingWorkoutSet, weightText: String, repetitionsText: String, rpeText: String,
    unit: MassUnit, locale: Locale, in context: ModelContext, completedAt: Date = .now
  ) throws {
    var draft = WorkoutSetDraft()
    draft.weight = weightText
    draft.repetitions = repetitionsText
    draft.effort = rpeText
    draft.massUnit = unit
    draft.kind = set.kind
    draft.customKindName = set.customSetKindName
    draft.counting = set.counting
    try complete(set, draft: draft, locale: locale, in: context, completedAt: completedAt)
  }

  static func complete(
    _ set: TrainingWorkoutSet, draft: WorkoutSetDraft, locale: Locale,
    in context: ModelContext, completedAt: Date = .now,
    bodyweight: WorkoutBodyweight? = nil, restSeconds: Double? = nil
  ) throws {
    guard let row = set.workoutExercise, let workout = row.workout, workout.isActive,
      completedAt.timeIntervalSince1970.isFinite, completedAt >= workout.startedAt
    else { throw TrainingWorkoutError.invalidOperation }
    // Edits retain the captured reading unless the caller explicitly supplies a new one.
    let capturedBodyweight =
      try bodyweight ?? savedBodyweight(for: set)
      ?? (row.metric.usesBodyweight ? latestBodyweight(at: completedAt, in: context) : nil)
    if let capturedBodyweight, capturedBodyweight.recordedAt > completedAt {
      throw TrainingWorkoutError.missingBodyweight
    }
    let values: WorkoutSetValues
    do {
      values = try draft.validated(for: row.metric, bodyweight: capturedBodyweight, locale: locale)
    } catch let error as WorkoutSetValidationError { throw map(error) }

    let duration = restSeconds ?? set.plannedRestSeconds ?? row.exercise?.defaultRestSeconds
    let timer: WorkoutRestTimer?
    if let duration {
      do {
        timer = try WorkoutRestTimer(
          workoutID: workout.id, setID: set.id, startedAt: completedAt, durationSeconds: duration)
      } catch { throw TrainingWorkoutError.invalidRestDuration }
    } else {
      timer = nil
    }
    // Do not restart a countdown when an already-completed set is corrected.
    let wasCompleted = set.completedAt != nil
    let timerData = try timer.map { try JSONEncoder().encode($0) }
    apply(values, to: set)
    if row.metricTypeSnapshotRawValue == nil {
      row.metricTypeSnapshotRawValue = values.metric.rawValue
    }
    set.completedAt = completedAt
    set.plannedRestSeconds = duration
    if !wasCompleted { workout.restTimerStateData = timerData }
    try save(context)
  }

  static func copyLastSet(to target: TrainingWorkoutSet, in context: ModelContext) throws {
    guard let row = target.workoutExercise,
      let source = row.sortedSets.last(where: { $0.position < target.position })
    else { throw TrainingWorkoutError.invalidOperation }
    try copy(source, to: target, in: context)
  }

  static func copy(
    _ source: TrainingWorkoutSet, to target: TrainingWorkoutSet, in context: ModelContext
  ) throws {
    guard source.id != target.id, target.completedAt == nil,
      target.workoutExercise?.workout?.isActive == true,
      let sourceExerciseID = source.workoutExercise?.exercise?.id,
      sourceExerciseID == target.workoutExercise?.exercise?.id
    else { throw TrainingWorkoutError.invalidOperation }
    let sourceMetric =
      WorkoutMetric(rawValue: source.metricTypeSnapshotRawValue ?? "")
      ?? (source.completedAt == nil ? source.workoutExercise?.metric : .weightAndReps)
      ?? .weightAndReps
    guard sourceMetric == target.workoutExercise?.metric else {
      throw TrainingWorkoutError.metricMismatch
    }
    copyTargets(from: source, to: target)
    try save(context)
  }

  static func fillRemaining(
    after source: TrainingWorkoutSet, in context: ModelContext
  ) throws {
    guard let row = source.workoutExercise, row.workout?.isActive == true else {
      throw TrainingWorkoutError.invalidOperation
    }
    for target in row.sortedSets
    where target.position > source.position && target.completedAt == nil {
      copyTargets(from: source, to: target)
    }
    try save(context)
  }

  static func duplicate(
    _ source: TrainingWorkoutSet, in context: ModelContext
  ) throws -> TrainingWorkoutSet {
    guard let row = source.workoutExercise, row.workout?.isActive == true else {
      throw TrainingWorkoutError.invalidOperation
    }
    let ordered = row.sortedSets
    guard let index = ordered.firstIndex(where: { $0.id == source.id }) else {
      throw TrainingWorkoutError.invalidOperation
    }
    let set = TrainingWorkoutSet(position: index + 1)
    copyTargets(from: source, to: set)
    context.insert(set)
    row.sets.append(set)
    set.workoutExercise = row
    var updated = ordered
    updated.insert(set, at: index + 1)
    for (position, entry) in updated.enumerated() { entry.position = position }
    try save(context)
    return set
  }

  /// IDs must be a permutation of all the row's sets; partial orders are rejected.
  static func reorder(
    _ row: TrainingWorkoutExercise, orderedIDs: [UUID], in context: ModelContext
  ) throws {
    guard row.workout?.isActive == true, orderedIDs.count == row.sets.count,
      Set(orderedIDs).count == orderedIDs.count, Set(orderedIDs) == Set(row.sets.map(\.id))
    else { throw TrainingWorkoutError.invalidOperation }
    let byID = Dictionary(uniqueKeysWithValues: row.sets.map { ($0.id, $0) })
    for (position, id) in orderedIDs.enumerated() { byID[id]?.position = position }
    try save(context)
  }

  static func delete(_ set: TrainingWorkoutSet, in context: ModelContext) throws {
    guard let row = set.workoutExercise, let workout = row.workout, workout.isActive else {
      throw TrainingWorkoutError.invalidOperation
    }
    try TrainingWorkoutRestTimer.clearIfOwned(by: set, in: workout)
    let remaining = row.sortedSets.filter { $0.id != set.id }
    context.delete(set)
    for (position, entry) in remaining.enumerated() { entry.position = position }
    try save(context)
  }

  static func undo(_ set: TrainingWorkoutSet, in context: ModelContext) throws {
    guard let workout = set.workoutExercise?.workout, workout.isActive else {
      throw TrainingWorkoutError.invalidOperation
    }
    try TrainingWorkoutRestTimer.clearIfOwned(by: set, in: workout)
    set.completedAt = nil
    set.actualRestSeconds = nil
    try save(context)
  }

  static func finish(
    _ workout: TrainingWorkout, in context: ModelContext, completedAt: Date = .now
  ) throws {
    guard workout.isActive, completedAt.timeIntervalSince1970.isFinite,
      completedAt >= workout.startedAt,
      workout.completedSets.allSatisfy({ $0.completedAt! <= completedAt })
    else { throw TrainingWorkoutError.invalidOperation }
    workout.completedAt = completedAt
    workout.restTimerStateData = nil
    try save(context)
  }

  private static func latestBodyweight(
    at date: Date, in context: ModelContext
  ) throws -> WorkoutBodyweight? {
    // Invalid/future readings are not silently used. Tie-breaks are deterministic.
    let readings = try context.fetch(FetchDescriptor<WeightEntry>())
      .filter {
        $0.date.timeIntervalSince1970.isFinite && $0.date <= date
          && $0.weightInPounds.isFinite && $0.weightInPounds > 0
      }
      .sorted {
        $0.date == $1.date ? $0.id.uuidString > $1.id.uuidString : $0.date > $1.date
      }
    guard let latest = readings.first else { return nil }
    return try WorkoutBodyweight(
      kilograms: MassUnit.pounds.kilograms(from: latest.weightInPounds), sourceID: latest.id,
      recordedAt: latest.date)
  }

  private static func savedBodyweight(for set: TrainingWorkoutSet) throws -> WorkoutBodyweight? {
    guard let kilograms = set.bodyweightKilograms, let recordedAt = set.bodyweightRecordedAt else {
      return nil
    }
    return try WorkoutBodyweight(
      kilograms: kilograms, sourceID: set.bodyweightEntryID, recordedAt: recordedAt)
  }

  private static func apply(_ values: WorkoutSetValues, to set: TrainingWorkoutSet) {
    set.metricTypeSnapshotRawValue = values.metric.rawValue
    set.enteredWeight = values.enteredWeight ?? 0
    set.enteredWeightUnitRawValue = values.massUnit.rawValue
    set.weightKilograms = values.weightKilograms ?? 0
    set.repetitions = values.repetitions ?? 0
    set.durationSeconds = values.durationSeconds
    set.enteredDistance = values.enteredDistance
    set.enteredDistanceUnitRawValue =
      values.enteredDistance == nil ? nil : values.distanceUnit.rawValue
    set.distanceMeters = values.distanceMeters
    set.bodyweightKilograms = values.bodyweight?.kilograms
    set.bodyweightEntryID = values.bodyweight?.sourceID
    set.bodyweightRecordedAt = values.bodyweight?.recordedAt
    set.rpe = values.rpe
    set.rir = values.rir
    set.sideRawValue = values.side.rawValue
    set.kind = values.kind
    set.customSetKindName = values.customKindName
    set.countsTowardVolume = values.counting.volume
    set.countsTowardHardSets = values.counting.hardSets
    set.countsTowardRecords = values.counting.records
  }

  private static func copyTargets(from source: TrainingWorkoutSet, to target: TrainingWorkoutSet) {
    target.metricTypeSnapshotRawValue = source.metricTypeSnapshotRawValue
    target.enteredWeight = source.enteredWeight
    target.enteredWeightUnitRawValue = source.enteredWeightUnitRawValue
    target.weightKilograms = source.weightKilograms
    target.repetitions = source.repetitions
    target.durationSeconds = source.durationSeconds
    target.enteredDistance = source.enteredDistance
    target.enteredDistanceUnitRawValue = source.enteredDistanceUnitRawValue
    target.distanceMeters = source.distanceMeters
    target.kind = source.kind
    target.customSetKindName = source.customSetKindName
    target.countsTowardVolume = source.countsTowardVolume
    target.countsTowardHardSets = source.countsTowardHardSets
    target.countsTowardRecords = source.countsTowardRecords
    target.sideRawValue = source.sideRawValue
    target.plannedRestSeconds = source.plannedRestSeconds
    target.rpe = nil
    target.rir = nil
    target.bodyweightKilograms = nil
    target.bodyweightEntryID = nil
    target.bodyweightRecordedAt = nil
    target.actualRestSeconds = nil
  }

  private static func map(_ error: WorkoutSetValidationError) -> TrainingWorkoutError {
    switch error {
    case .invalidWeight: .invalidWeight
    case .invalidRepetitions: .invalidRepetitions
    case .invalidDuration: .invalidDuration
    case .invalidDistance: .invalidDistance
    case .invalidEffort: .invalidRPE
    case .missingBodyweight, .invalidBodyweight: .missingBodyweight
    case .excessiveAssistance: .excessiveAssistance
    case .invalidCustomKind: .invalidCustomKind
    case .overflow: .overflow
    }
  }

  static func save(_ context: ModelContext) throws {
    do { try context.save() } catch {
      context.rollback()
      throw error
    }
  }
}
