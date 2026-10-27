import CaliberCore
import Foundation
import SwiftData

enum TrainingWorkoutError: LocalizedError, Equatable {
  case invalidWeight
  case invalidRepetitions
  case invalidRPE

  var errorDescription: String? {
    switch self {
    case .invalidWeight: "Enter a weight of zero or greater."
    case .invalidRepetitions: "Enter a whole number of repetitions greater than zero."
    case .invalidRPE: "RPE must be between 1 and 10, or left blank."
    }
  }
}

@MainActor
enum TrainingWorkoutLogger {
  static func start(in context: ModelContext, date: Date = .now) throws -> TrainingWorkout {
    let workout = TrainingWorkout(
      name: "Workout · " + date.formatted(date: .abbreviated, time: .omitted), startedAt: date)
    context.insert(workout)
    try context.save()
    return workout
  }

  /// Starts a session with an earlier workout's name and exercises: one open set for each set
  /// finished last time, filled with the weight and repetitions logged then. Nothing is marked
  /// complete, and RPE is left blank because effort must not be assumed.
  static func repeating(
    _ previous: TrainingWorkout, in context: ModelContext, date: Date = .now
  ) throws -> TrainingWorkout {
    let workout = TrainingWorkout(name: previous.name, startedAt: date)
    context.insert(workout)
    for (position, row) in previous.sortedExercises.enumerated() {
      guard let exercise = row.exercise else { continue }
      let copy = TrainingWorkoutExercise(position: position, exercise: exercise)
      context.insert(copy)
      workout.exercises.append(copy)
      copy.workout = workout
      let finished = row.sortedSets.filter { $0.completedAt != nil }
      for index in 0..<max(finished.count, 1) {
        let set = TrainingWorkoutSet(position: index)
        if finished.indices.contains(index) {
          let old = finished[index]
          set.enteredWeight = old.enteredWeight
          set.enteredWeightUnitRawValue = old.enteredWeightUnitRawValue
          set.weightKilograms = old.weightKilograms
          set.repetitions = old.repetitions
          set.isWarmup = old.isWarmup
        }
        context.insert(set)
        copy.sets.append(set)
        set.workoutExercise = copy
      }
    }
    do {
      try context.save()
    } catch {
      context.rollback()
      throw error
    }
    return workout
  }

  static func addExercise(
    _ exercise: TrainingExercise, to workout: TrainingWorkout, in context: ModelContext
  ) throws -> TrainingWorkoutExercise {
    let row = TrainingWorkoutExercise(
      position: (workout.exercises.map(\.position).max() ?? -1) + 1, exercise: exercise)
    context.insert(row)
    workout.exercises.append(row)
    row.workout = workout
    _ = try addSet(to: row, in: context, save: false)
    try context.save()
    return row
  }

  static func addSet(
    to exercise: TrainingWorkoutExercise, in context: ModelContext, save: Bool = true
  ) throws -> TrainingWorkoutSet {
    let set = TrainingWorkoutSet(position: (exercise.sets.map(\.position).max() ?? -1) + 1)
    if let previous = exercise.sortedSets.last {
      set.enteredWeight = previous.enteredWeight
      set.enteredWeightUnitRawValue = previous.enteredWeightUnitRawValue
      set.weightKilograms = previous.weightKilograms
      set.repetitions = previous.repetitions
      set.rpe = previous.rpe
      set.isWarmup = previous.isWarmup
    }
    context.insert(set)
    exercise.sets.append(set)
    set.workoutExercise = exercise
    if save { try context.save() }
    return set
  }

  static func complete(
    _ set: TrainingWorkoutSet, weightText: String, repetitionsText: String, rpeText: String,
    unit: MassUnit, locale: Locale, in context: ModelContext, completedAt: Date = .now
  ) throws {
    let enteredWeight: EnteredMass
    do {
      enteredWeight = try EnteredMass(text: weightText, unit: unit, locale: locale)
    } catch {
      throw TrainingWorkoutError.invalidWeight
    }
    guard let repetitions = Int(repetitionsText), repetitions > 0,
      String(repetitions) == repetitionsText.trimmingCharacters(in: .whitespacesAndNewlines)
    else { throw TrainingWorkoutError.invalidRepetitions }

    let trimmedRPE = rpeText.trimmingCharacters(in: .whitespacesAndNewlines)
    let rpe: Double?
    if trimmedRPE.isEmpty {
      rpe = nil
    } else {
      do {
        let value = try QuantityParsing.nonnegative(trimmedRPE, locale: locale)
        guard (1...10).contains(value) else { throw TrainingWorkoutError.invalidRPE }
        rpe = value
      } catch {
        throw TrainingWorkoutError.invalidRPE
      }
    }

    set.enteredWeight = unit.fromKilograms(enteredWeight.kilograms)
    set.enteredWeightUnitRawValue = unit.rawValue
    set.weightKilograms = enteredWeight.kilograms
    set.repetitions = repetitions
    set.rpe = rpe
    set.completedAt = completedAt
    try context.save()
  }

  static func undo(_ set: TrainingWorkoutSet, in context: ModelContext) throws {
    set.completedAt = nil
    try context.save()
  }

  static func finish(
    _ workout: TrainingWorkout, in context: ModelContext, completedAt: Date = .now
  ) throws {
    workout.completedAt = completedAt
    try context.save()
  }
}
