import CaliberCore
import Foundation
import SwiftData
import Testing

@testable import Caliber__DEV_

@Suite(.serialized) @MainActor
struct CustomExerciseEditorTests {
  private func container() throws -> ModelContainer {
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

  @Test func customExerciseIsSavedAndCanBeLoggedWithoutAnAccount() throws {
    let store = try container()
    let context = ModelContext(store)
    context.autosaveEnabled = false
    let created = try CustomExerciseEditor.create(
      name: "  Cable Press Variation  ", aliases: "  my cable press  ", in: context)
    let reader = ModelContext(store)
    let saved = try #require(reader.fetch(FetchDescriptor<TrainingExercise>()).first)
    #expect(saved.id == created.id)
    #expect(saved.name == "Cable Press Variation")
    #expect(saved.aliases == "my cable press")
    #expect(saved.isCustom && saved.metricType == .weightAndReps)
    let workout = try TrainingWorkoutLogger.start(in: context)
    let row = try TrainingWorkoutLogger.addExercise(created, to: workout, in: context)
    let set = try #require(row.sortedSets.first)
    try TrainingWorkoutLogger.complete(
      set, weightText: "40", repetitionsText: "8", rpeText: "", unit: .pounds,
      locale: Locale(identifier: "en_US"), in: context)
    #expect(workout.completedSets.count == 1)
    #expect(workout.completedSets.first?.workoutExercise?.exercise?.id == created.id)
  }

  @Test func blankNamesDoNotCreateRows() throws {
    let store = try container()
    let context = ModelContext(store)
    for name in ["", "   ", "\n\t"] {
      #expect(throws: CustomExerciseError.missingName) {
        try CustomExerciseEditor.create(name: name, aliases: "", in: context)
      }
    }
    #expect(try context.fetchCount(FetchDescriptor<TrainingExercise>()) == 0)
  }

  @Test func duplicateNamesRespectCaseSpacingAccentsAndExistingSeedRows() throws {
    let store = try container()
    let context = ModelContext(store)
    let seed = TrainingExercise(name: "Café Press", isCustom: false)
    context.insert(seed)
    try context.save()
    for name in ["Café Press", " CAFE press ", "cafe   press", "ＣＡＦＥ press"] {
      #expect(throws: CustomExerciseError.duplicateName) {
        try CustomExerciseEditor.create(name: name, aliases: "", in: context)
      }
    }
    #expect(try context.fetchCount(FetchDescriptor<TrainingExercise>()) == 1)
    #expect(seed.name == "Café Press" && !seed.isCustom)
    _ = try CustomExerciseEditor.create(name: "Café Press — Seated", aliases: "", in: context)
    #expect(try context.fetchCount(FetchDescriptor<TrainingExercise>()) == 2)
  }
}
