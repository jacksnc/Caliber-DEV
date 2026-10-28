import CaliberCore
import Foundation
import SwiftData
import Testing

@testable import Caliber__DEV_

@Suite(.serialized) @MainActor
struct WorkoutEnginePersistenceTests {
  private let epoch = Date(timeIntervalSince1970: 1_700_000_000)
  private let locale = Locale(identifier: "en_US")

  private func container(at url: URL? = nil) throws -> ModelContainer {
    let schema = Schema([
      TrainingExercise.self, TrainingWorkout.self, TrainingWorkoutExercise.self,
      TrainingWorkoutSet.self, WeightEntry.self, ProgressEntry.self, ProgressPhoto.self,
    ])
    let configuration =
      if let url {
        ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
      } else {
        ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
      }
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  private func draft() -> WorkoutSetDraft {
    var result = WorkoutSetDraft()
    result.weight = "20"
    result.massUnit = .kilograms
    result.repetitions = "5"
    result.durationSeconds = "30"
    result.distance = "1.5"
    result.distanceUnit = .kilometers
    result.effort = "2"
    result.effortScale = .rir
    return result
  }

  private func seedDiskMetrics(at url: URL) throws -> UUID {
    return try autoreleasepool {
      let store = try container(at: url)
      let context = ModelContext(store)
      context.autosaveEnabled = false
      context.insert(WeightEntry(date: epoch, weightInPounds: 80 / 0.45359237))
      context.insert(WeightEntry(date: epoch.addingTimeInterval(999), weightInPounds: 999))
      let workout = try TrainingWorkoutLogger.start(in: context, date: epoch)
      for metric in WorkoutMetric.allCases {
        let exercise = TrainingExercise(
          name: metric.rawValue,
          metricType: try #require(ExerciseMetricType(rawValue: metric.rawValue)))
        exercise.defaultRestSeconds = 90
        context.insert(exercise)
        let row = try TrainingWorkoutLogger.addExercise(exercise, to: workout, in: context)
        let set = try #require(row.sortedSets.first)
        try TrainingWorkoutLogger.complete(
          set, draft: draft(), locale: locale, in: context,
          completedAt: epoch.addingTimeInterval(100))
      }
      return workout.id
    }
  }

  @Test func allMetricsAndTimerSurviveClosedDiskStore() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    // SwiftData's migration coordinator may retain handles beyond this scope.
    // Keep synthetic temp files until the test host exits; never unlink open stores.
    try autoreleasepool {
      let url = directory.appendingPathComponent("Workout.sqlite")
      let workoutID = try seedDiskMetrics(at: url)
      let store = try container(at: url)
      let context = ModelContext(store)
      let workout = try #require(context.fetch(FetchDescriptor<TrainingWorkout>()).first)
      #expect(workout.id == workoutID)
      #expect(workout.isActive)
      #expect(workout.completedSets.count == 9)
      #expect(abs(workout.volumeKilograms - 1_300) < 1e-8)
      for row in workout.sortedExercises {
        let set = try #require(row.sortedSets.first)
        #expect(set.metricTypeSnapshotRawValue == row.metric.rawValue)
        #expect(set.durationSeconds == (row.metric.usesDuration ? 30 : nil))
        #expect(set.distanceMeters == (row.metric.usesDistance ? 1_500 : nil))
        #expect(set.enteredDistance == (row.metric.usesDistance ? 1.5 : nil))
        #expect(set.rir == 2)
        #expect(set.rpe == nil)
        if row.metric.usesBodyweight {
          #expect(abs(try #require(set.bodyweightKilograms) - 80) < 1e-8)
          #expect(set.bodyweightRecordedAt == epoch)
          #expect(set.bodyweightEntryID != nil)
        }
      }
      let savedTimer = try TrainingWorkoutRestTimer.state(for: workout)
      let rest = try #require(savedTimer)
      #expect(rest.remaining(at: epoch.addingTimeInterval(140)) == 50)
      try TrainingWorkoutRestTimer.adjust(workout, by: 15, in: context)
      try TrainingWorkoutRestTimer.beginNextSet(
        workout, at: epoch.addingTimeInterval(250), in: context)
      let previous = try #require(workout.completedSets.first(where: { $0.id == rest.setID }))
      #expect(previous.actualRestSeconds == 150)
      let otherContext = ModelContext(store)
      let saved = try #require(otherContext.fetch(FetchDescriptor<TrainingWorkout>()).first)
      #expect(try TrainingWorkoutRestTimer.state(for: saved)?.actualRestSeconds == 150)
      #expect(throws: WorkoutRestTimerError.alreadyEnded) {
        try TrainingWorkoutRestTimer.beginNextSet(
          saved, at: epoch.addingTimeInterval(300), in: otherContext)
      }
    }
  }

  @Test func copyingAndEditingDoNotDuplicateCompletionOrEffort() throws {
    let store = try container()
    let context = ModelContext(store)
    let exercise = TrainingExercise(name: "Copy test")
    context.insert(exercise)
    let workout = try TrainingWorkoutLogger.start(in: context, date: epoch)
    let row = try TrainingWorkoutLogger.addExercise(exercise, to: workout, in: context)
    let source = try #require(row.sortedSets.first)
    var values = draft()
    values.kind = .topSet
    try TrainingWorkoutLogger.complete(
      source, draft: values, locale: locale, in: context, completedAt: epoch.addingTimeInterval(1))
    let second = try TrainingWorkoutLogger.addSet(to: row, in: context)
    #expect(second.kind == .topSet)
    #expect(second.rir == nil && second.rpe == nil && second.completedAt == nil)
    let third = try TrainingWorkoutLogger.addSet(to: row, in: context)
    third.repetitions = 99
    try TrainingWorkoutLogger.fillRemaining(after: source, in: context)
    #expect(third.repetitions == 5)
    let duplicate = try TrainingWorkoutLogger.duplicate(source, in: context)
    #expect(row.sortedSets.map(\.id) == [source.id, duplicate.id, second.id, third.id])
    #expect(duplicate.completedAt == nil && duplicate.rir == nil)
    #expect(workout.completedSets.count == 1)
    try TrainingWorkoutLogger.reorder(
      row, orderedIDs: row.sortedSets.reversed().map(\.id), in: context)
    #expect(row.sortedSets.map(\.position) == [0, 1, 2, 3])
    #expect(row.sortedSets.first?.id == third.id)
    #expect(throws: TrainingWorkoutError.invalidOperation) {
      try TrainingWorkoutLogger.reorder(row, orderedIDs: [source.id, source.id], in: context)
    }
    try TrainingWorkoutLogger.delete(source, in: context)
    #expect(workout.volumeKilograms == 0)
    #expect(row.sortedSets.map(\.position) == [0, 1, 2])
    let reopened = ModelContext(store)
    #expect(try reopened.fetch(FetchDescriptor<TrainingWorkoutSet>()).count == 3)
  }

  @Test func invalidInputOrRestDoesNotOverwriteCompletedSet() throws {
    let store = try container()
    let context = ModelContext(store)
    let exercise = TrainingExercise(name: "Atomic validation", metricType: .distanceAndDuration)
    context.insert(exercise)
    let workout = try TrainingWorkoutLogger.start(in: context, date: epoch)
    let row = try TrainingWorkoutLogger.addExercise(exercise, to: workout, in: context)
    let set = try #require(row.sortedSets.first)
    try TrainingWorkoutLogger.complete(
      set, draft: draft(), locale: locale, in: context, completedAt: epoch.addingTimeInterval(1),
      restSeconds: 90)
    let timerData = workout.restTimerStateData
    var invalid = draft()
    invalid.distance = "-1"
    #expect(throws: TrainingWorkoutError.invalidDistance) {
      try TrainingWorkoutLogger.complete(
        set, draft: invalid, locale: locale, in: context, completedAt: epoch.addingTimeInterval(2))
    }
    invalid = draft()
    invalid.distance = "5"
    #expect(throws: TrainingWorkoutError.invalidRestDuration) {
      try TrainingWorkoutLogger.complete(
        set, draft: invalid, locale: locale, in: context, completedAt: epoch.addingTimeInterval(2),
        restSeconds: -1)
    }
    #expect(set.enteredDistance == 1.5)
    #expect(set.completedAt == epoch.addingTimeInterval(1))
    #expect(workout.restTimerStateData == timerData)
    try TrainingWorkoutLogger.complete(
      set, draft: invalid, locale: locale, in: context, completedAt: epoch.addingTimeInterval(2))
    #expect(set.distanceMeters == 5_000)
    #expect(workout.restTimerStateData == timerData)
    try TrainingWorkoutLogger.undo(set, in: context)
    #expect(workout.restTimerStateData == nil)
  }

  @Test func previousPerformanceUsesLastFinishedMatchingGymAndMetric() throws {
    let store = try container()
    let context = ModelContext(store)
    let exercise = TrainingExercise(name: "History test")
    context.insert(exercise)
    let gym = UUID()
    func past(start: Double, end: Double, gymID: UUID?, weight: String) throws -> TrainingWorkout {
      let workout = try TrainingWorkoutLogger.start(
        in: context, date: epoch.addingTimeInterval(start))
      workout.gymID = gymID
      let row = try TrainingWorkoutLogger.addExercise(exercise, to: workout, in: context)
      let set = try #require(row.sortedSets.first)
      var input = draft()
      input.weight = weight
      try TrainingWorkoutLogger.complete(
        set, draft: input, locale: locale, in: context,
        completedAt: epoch.addingTimeInterval(start + 1))
      try TrainingWorkoutLogger.finish(
        workout, in: context, completedAt: epoch.addingTimeInterval(end))
      return workout
    }
    _ = try past(start: 1, end: 50, gymID: gym, weight: "50")
    _ = try past(start: 2, end: 40, gymID: gym, weight: "40")
    _ = try past(start: 60, end: 70, gymID: UUID(), weight: "70")
    _ = try past(start: 200, end: 250, gymID: gym, weight: "250")
    let current = try TrainingWorkoutLogger.start(in: context, date: epoch.addingTimeInterval(100))
    current.gymID = gym
    let row = try TrainingWorkoutLogger.addExercise(exercise, to: current, in: context)
    let previous = try TrainingWorkoutHistory.previousSets(for: row, in: context)
    #expect(previous.count == 1 && previous.first?.enteredWeight == 50)
    let target = try #require(row.sortedSets.first)
    try TrainingWorkoutHistory.copyPrevious(to: target, in: context)
    #expect(target.enteredWeight == 50)
    #expect(target.rir == nil && target.completedAt == nil)
    row.metricTypeSnapshotRawValue = WorkoutMetric.duration.rawValue
    #expect(try TrainingWorkoutHistory.previousSets(for: row, in: context).isEmpty)
    #expect(throws: TrainingWorkoutError.metricMismatch) {
      try TrainingWorkoutLogger.copy(previous[0], to: target, in: context)
    }
  }

  @Test func capturedBodyweightAndExerciseMetricDoNotChangeWithSourceEdits() throws {
    let store = try container()
    let context = ModelContext(store)
    let reading = WeightEntry(date: epoch, weightInPounds: 80 / 0.45359237)
    context.insert(reading)
    let exercise = TrainingExercise(name: "Weighted pull-up", metricType: .weightedBodyweight)
    context.insert(exercise)
    let workout = try TrainingWorkoutLogger.start(in: context, date: epoch)
    let row = try TrainingWorkoutLogger.addExercise(exercise, to: workout, in: context)
    // A migrated row has no metric snapshot until its first new completion.
    row.metricTypeSnapshotRawValue = nil
    let set = try #require(row.sortedSets.first)
    try TrainingWorkoutLogger.complete(
      set, draft: draft(), locale: locale, in: context, completedAt: epoch.addingTimeInterval(1))
    #expect(abs(workout.volumeKilograms - 500) < 1e-8)
    reading.weightInPounds = 300
    exercise.metricType = .duration
    try context.save()
    #expect(row.metric == .weightedBodyweight)
    #expect(abs(workout.volumeKilograms - 500) < 1e-8)
    try TrainingWorkoutLogger.complete(
      set, draft: draft(), locale: locale, in: context, completedAt: epoch.addingTimeInterval(2))
    #expect(abs(workout.volumeKilograms - 500) < 1e-8)
    let duplicate = try TrainingWorkoutLogger.duplicate(set, in: context)
    #expect(duplicate.bodyweightKilograms == nil)
    #expect(duplicate.bodyweightEntryID == nil)
  }

  @Test func warmupCompatibilityAndLegacyVolumeRemainCorrect() throws {
    let store = try container()
    let context = ModelContext(store)
    let exercise = TrainingExercise(name: "Legacy", metricType: .duration)
    context.insert(exercise)
    let workout = try TrainingWorkoutLogger.start(in: context, date: epoch)
    let row = try TrainingWorkoutLogger.addExercise(exercise, to: workout, in: context)
    let set = try #require(row.sortedSets.first)
    set.enteredWeight = 100
    set.weightKilograms = 100
    set.repetitions = 5
    set.completedAt = epoch.addingTimeInterval(1)
    // A pre-upgrade row lacks a metric snapshot: it keeps its original rep tonnage.
    #expect(set.metricTypeSnapshotRawValue == nil)
    #expect(set.countedVolumeKilograms == 500)
    set.isWarmup = true
    #expect(set.countedVolumeKilograms == 0)
    set.isWarmup = false
    #expect(set.countedVolumeKilograms == 500)
    row.metricTypeSnapshotRawValue = WorkoutMetric.weightAndReps.rawValue
    set.isWarmup = true
    try TrainingWorkoutLogger.complete(
      set,
      draft: {
        var input = draft()
        input.kind = .warmup
        return input
      }(), locale: locale, in: context, completedAt: epoch.addingTimeInterval(2))
    let working = try TrainingWorkoutLogger.addSet(to: row, in: context)
    working.isWarmup = false
    try TrainingWorkoutLogger.complete(
      working, weightText: "100", repetitionsText: "5", rpeText: "8", unit: .kilograms,
      locale: locale, in: context, completedAt: epoch.addingTimeInterval(3))
    #expect(working.countedVolumeKilograms == 500)
    #expect(workout.volumeKilograms == 500)
  }

  @Test func timerSkipUndoDeleteAndFinishHaveExplicitLifecycles() throws {
    let store = try container()
    let context = ModelContext(store)
    let exercise = TrainingExercise(name: "Rest lifecycle")
    exercise.defaultRestSeconds = 90
    context.insert(exercise)
    let workout = try TrainingWorkoutLogger.start(in: context, date: epoch)
    let row = try TrainingWorkoutLogger.addExercise(exercise, to: workout, in: context)
    let first = try #require(row.sortedSets.first)
    try TrainingWorkoutLogger.complete(
      first, draft: draft(), locale: locale, in: context, completedAt: epoch.addingTimeInterval(1))
    try TrainingWorkoutRestTimer.skip(workout, at: epoch.addingTimeInterval(10), in: context)
    #expect(first.actualRestSeconds == nil)
    #expect(try TrainingWorkoutRestTimer.state(for: workout)?.endReason == .skipped)
    #expect(throws: WorkoutRestTimerError.alreadyEnded) {
      try TrainingWorkoutRestTimer.adjust(workout, by: 15, in: context)
    }
    let second = try TrainingWorkoutLogger.addSet(to: row, in: context)
    try TrainingWorkoutLogger.complete(
      second, draft: draft(), locale: locale, in: context, completedAt: epoch.addingTimeInterval(20)
    )
    #expect(try TrainingWorkoutRestTimer.state(for: workout)?.setID == second.id)
    try TrainingWorkoutLogger.delete(second, in: context)
    #expect(workout.restTimerStateData == nil)
    let third = try TrainingWorkoutLogger.addSet(to: row, in: context)
    try TrainingWorkoutLogger.complete(
      third, draft: draft(), locale: locale, in: context, completedAt: epoch.addingTimeInterval(30))
    try TrainingWorkoutLogger.finish(
      workout, in: context, completedAt: epoch.addingTimeInterval(40))
    #expect(workout.restTimerStateData == nil)
    #expect(throws: TrainingWorkoutError.invalidOperation) {
      try TrainingWorkoutLogger.undo(first, in: context)
    }
    #expect(throws: TrainingWorkoutError.invalidOperation) {
      try TrainingWorkoutLogger.addSet(to: row, in: context)
    }
    #expect(workout.completedSets.count == 2)
  }

  @Test func missingOrFutureBodyweightDoesNotCompleteASet() throws {
    let store = try container()
    let context = ModelContext(store)
    let exercise = TrainingExercise(name: "Bodyweight validation", metricType: .bodyweightAndReps)
    context.insert(exercise)
    context.insert(WeightEntry(date: epoch.addingTimeInterval(100), weightInPounds: 180))
    let workout = try TrainingWorkoutLogger.start(in: context, date: epoch)
    let row = try TrainingWorkoutLogger.addExercise(exercise, to: workout, in: context)
    let set = try #require(row.sortedSets.first)
    #expect(throws: TrainingWorkoutError.missingBodyweight) {
      try TrainingWorkoutLogger.complete(
        set, draft: draft(), locale: locale, in: context, completedAt: epoch.addingTimeInterval(1))
    }
    let future = try WorkoutBodyweight(kilograms: 80, recordedAt: epoch.addingTimeInterval(100))
    #expect(throws: TrainingWorkoutError.missingBodyweight) {
      try TrainingWorkoutLogger.complete(
        set, draft: draft(), locale: locale, in: context, completedAt: epoch.addingTimeInterval(1),
        bodyweight: future)
    }
    #expect(set.completedAt == nil && set.bodyweightKilograms == nil)
    #expect(workout.volumeKilograms == 0)
  }
}
