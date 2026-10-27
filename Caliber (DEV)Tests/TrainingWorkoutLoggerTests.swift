import CaliberCore
import Foundation
import SwiftData
import Testing

@testable import Caliber__DEV_

@MainActor
private func trainingContainer() throws -> ModelContainer {
  let schema = Schema([
    TrainingExercise.self, TrainingWorkout.self, TrainingWorkoutExercise.self,
    TrainingWorkoutSet.self,
  ])
  return try ModelContainer(
    for: schema,
    configurations: [
      ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    ])
}

@MainActor @Test func completedSetIsImmediatelyDurableAndWorkoutResumes() throws {
  let container = try trainingContainer()
  let context = ModelContext(container)
  context.autosaveEnabled = false
  let exercise = TrainingExercise(name: "Persistence Squat")
  context.insert(exercise)
  let workout = try TrainingWorkoutLogger.start(
    in: context, date: Date(timeIntervalSince1970: 1_700_000_000))
  let workoutExercise = try TrainingWorkoutLogger.addExercise(
    exercise, to: workout, in: context)
  let set = try #require(workoutExercise.sortedSets.first)

  try TrainingWorkoutLogger.complete(
    set, weightText: "225", repetitionsText: "5", rpeText: "8.5",
    unit: .pounds, locale: Locale(identifier: "en_US"), in: context,
    completedAt: Date(timeIntervalSince1970: 1_700_000_100))

  let reopened = ModelContext(container)
  reopened.autosaveEnabled = false
  let savedWorkout = try #require(reopened.fetch(FetchDescriptor<TrainingWorkout>()).first)
  let savedSet = try #require(savedWorkout.completedSets.first)
  #expect(savedWorkout.isActive)
  #expect(savedSet.enteredWeight == 225)
  #expect(savedSet.enteredWeightUnitRawValue == "lb")
  #expect(abs(savedSet.weightKilograms - 102.05828325) < 0.000_000_01)
  #expect(savedSet.repetitions == 5)
  #expect(savedSet.rpe == 8.5)
}

@MainActor @Test func invalidSetDoesNotOverwriteSavedValues() throws {
  let container = try trainingContainer()
  let context = ModelContext(container)
  context.autosaveEnabled = false
  let exercise = TrainingExercise(name: "Validation Press")
  context.insert(exercise)
  let workout = try TrainingWorkoutLogger.start(in: context)
  let row = try TrainingWorkoutLogger.addExercise(exercise, to: workout, in: context)
  let set = try #require(row.sortedSets.first)

  #expect(throws: TrainingWorkoutError.invalidRepetitions) {
    try TrainingWorkoutLogger.complete(
      set, weightText: "100", repetitionsText: "5.5", rpeText: "8",
      unit: .kilograms, locale: Locale(identifier: "en_US"), in: context)
  }
  #expect(set.completedAt == nil)
  #expect(set.weightKilograms == 0)
  #expect(set.repetitions == 0)
}

@MainActor @Test func repeatingCopiesFinishedSetsAsOpenSets() throws {
  let container = try trainingContainer()
  let context = ModelContext(container)
  context.autosaveEnabled = false
  let bench = TrainingExercise(name: "Repeat Bench")
  let fly = TrainingExercise(name: "Repeat Fly")
  context.insert(bench)
  context.insert(fly)
  let last = try TrainingWorkoutLogger.start(in: context)
  last.name = "Push A"
  let benchRow = try TrainingWorkoutLogger.addExercise(bench, to: last, in: context)
  for reps in ["6", "5"] {
    let set = try #require(benchRow.sortedSets.last { $0.completedAt == nil })
    try TrainingWorkoutLogger.complete(
      set, weightText: "200", repetitionsText: reps, rpeText: "9",
      unit: .pounds, locale: Locale(identifier: "en_US"), in: context)
    _ = try TrainingWorkoutLogger.addSet(to: benchRow, in: context)
  }
  _ = try TrainingWorkoutLogger.addExercise(fly, to: last, in: context)
  try TrainingWorkoutLogger.finish(last, in: context)

  let next = try TrainingWorkoutLogger.repeating(last, in: context)
  #expect(next.name == "Push A")
  #expect(next.isActive)
  #expect(next.completedSets.isEmpty)
  let rows = next.sortedExercises
  #expect(rows.map { $0.exercise?.name } == ["Repeat Bench", "Repeat Fly"])
  // Two finished bench sets become two open ones; the unfinished third is not copied.
  #expect(rows[0].sortedSets.map(\.repetitions) == [6, 5])
  #expect(rows[0].sortedSets.allSatisfy { $0.enteredWeight == 200 && $0.rpe == nil })
  // An exercise with nothing finished still gets one empty set to fill in.
  #expect(rows[1].sortedSets.count == 1)
  #expect(rows[1].sortedSets[0].repetitions == 0)
}

@MainActor @Test func warmupIsExcludedFromWorkoutVolume() throws {
  let container = try trainingContainer()
  let context = ModelContext(container)
  context.autosaveEnabled = false
  let exercise = TrainingExercise(name: "Volume Deadlift")
  context.insert(exercise)
  let workout = try TrainingWorkoutLogger.start(in: context)
  let row = try TrainingWorkoutLogger.addExercise(exercise, to: workout, in: context)
  let warmup = try #require(row.sortedSets.first)
  warmup.isWarmup = true
  try TrainingWorkoutLogger.complete(
    warmup, weightText: "100", repetitionsText: "10", rpeText: "",
    unit: .kilograms, locale: Locale(identifier: "en_US"), in: context)
  let working = try TrainingWorkoutLogger.addSet(to: row, in: context)
  working.isWarmup = false
  try TrainingWorkoutLogger.complete(
    working, weightText: "100", repetitionsText: "10", rpeText: "8",
    unit: .kilograms, locale: Locale(identifier: "en_US"), in: context)
  #expect(workout.completedSets.count == 2)
  #expect(workout.volumeKilograms == 1_000)
}
