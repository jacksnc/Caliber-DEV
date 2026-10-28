import CaliberCore
import Foundation
import SwiftData
import Testing

@testable import Caliber__DEV_

@Suite(.serialized) @MainActor
struct GoalSetupPersistenceTests {
  private func store(url: URL? = nil, includeSetup: Bool = true) throws -> ModelContainer {
    let schema =
      includeSetup
      ? Schema([UserProfile.self, NutritionGoalSetup.self]) : Schema([UserProfile.self])
    let configuration =
      url.map { ModelConfiguration(schema: schema, url: $0, cloudKitDatabase: .none) }
      ?? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    return try ModelContainer(for: schema, configurations: configuration)
  }

  private func plan(edited: Bool = false) throws -> GoalSetupPlan {
    try GoalSetupPlanner.make(
      input: EnergyTargetInput(
        weightKilograms: 80, heightCentimeters: 180, ageYears: 35,
        coefficient: .plusFive, activityMultiplier: 1.375, weeklyWeightChangePercent: 0.5,
        goal: .cut),
      targetWeightKilograms: 75,
      editedTargets: edited
        ? GoalMacroTargets(
          calories: 2345.123456789, protein: 151.25, carbohydrates: 245.75, fat: 68.875) : nil)
  }

  @Test func confirmationSavesOneProfileAndReopenableSetup() throws {
    let database = try store()
    let context = ModelContext(database)
    context.autosaveEnabled = false
    let expected = try plan()
    let profile = try GoalSetupEditor.save(expected, replacing: nil, in: context)
    let reader = ModelContext(database)
    let saved = try #require(reader.fetch(FetchDescriptor<UserProfile>()).first)
    let setup = try #require(try GoalSetupEditor.latest(for: profile.id, in: reader))
    #expect(saved.id == profile.id && saved.dailyCalorieGoal == expected.targets.calories)
    #expect(saved.proteinGoal == expected.targets.protein)
    #expect(setup.plan == expected)
    #expect(try reader.fetchCount(FetchDescriptor<UserProfile>()) == 1)
    #expect(try reader.fetchCount(FetchDescriptor<NutritionGoalSetup>()) == 1)
    try GoalSetupEditor.save(try plan(edited: true), replacing: profile, in: context)
    #expect(try context.fetchCount(FetchDescriptor<UserProfile>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<NutritionGoalSetup>()) == 1)
    #expect(try GoalSetupEditor.latest(for: profile.id, in: context)?.plan?.wasEdited == true)
  }

  @Test func failedSaveRestoresOnlyTheEditedRows() throws {
    enum Failure: Error { case refused }
    let database = try store()
    let context = ModelContext(database)
    context.autosaveEnabled = false
    let original = try plan()
    let profile = try GoalSetupEditor.save(original, replacing: nil, in: context)
    let setup = try #require(try GoalSetupEditor.latest(for: profile.id, in: context))
    let beforeData = setup.planData
    let unrelated = UserProfile(
      heightInInches: 70, startingWeight: 180, activityLevel: .sedentary,
      dailyCalorieGoal: 2200, proteinGoal: 150, carbGoal: 230, fatGoal: 70)
    context.insert(unrelated)
    try context.save()
    unrelated.proteinGoal = 175
    #expect(throws: Failure.refused) {
      try GoalSetupEditor.save(
        try plan(edited: true), replacing: profile, in: context, commit: { throw Failure.refused })
    }
    #expect(profile.dailyCalorieGoal == original.targets.calories)
    #expect(setup.planData == beforeData)
    #expect(unrelated.proteinGoal == 175)  // no global rollback of another edit
    let reader = ModelContext(database)
    #expect(
      try reader.fetch(FetchDescriptor<UserProfile>()).first { $0.id == profile.id }?
        .dailyCalorieGoal == original.targets.calories)
    try context.save()
    #expect(
      try ModelContext(database).fetch(FetchDescriptor<UserProfile>()).first {
        $0.id == unrelated.id
      }?.proteinGoal == 175)
  }

  @Test func failedCreationLeavesNoProfileOrSetup() throws {
    enum Failure: Error { case refused }
    let database = try store()
    let context = ModelContext(database)
    context.autosaveEnabled = false
    #expect(throws: Failure.refused) {
      try GoalSetupEditor.save(
        try plan(), replacing: nil, in: context, commit: { throw Failure.refused })
    }
    #expect(try context.fetchCount(FetchDescriptor<UserProfile>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<NutritionGoalSetup>()) == 0)
  }

  @Test func addingSetupEntityKeepsAnExistingDiskProfileAndTargets() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("profile.store")
    let id: UUID
    do {
      let old = try store(url: url, includeSetup: false)
      let context = ModelContext(old)
      let profile = UserProfile(
        heightInInches: 70, startingWeight: 180, activityLevel: .sedentary,
        dailyCalorieGoal: 2345.125, proteinGoal: 152.75, carbGoal: 240.5, fatGoal: 70.25)
      id = profile.id
      context.insert(profile)
      try context.save()
    }
    let reopened = try store(url: url)
    let context = ModelContext(reopened)
    let profile = try #require(context.fetch(FetchDescriptor<UserProfile>()).first)
    #expect(profile.id == id && profile.dailyCalorieGoal == 2345.125)
    #expect(profile.proteinGoal == 152.75 && profile.carbGoal == 240.5 && profile.fatGoal == 70.25)
    #expect(try context.fetchCount(FetchDescriptor<NutritionGoalSetup>()) == 0)
    try GoalSetupEditor.save(try plan(), replacing: profile, in: context)
    #expect(try GoalSetupEditor.latest(for: id, in: ModelContext(reopened))?.plan == plan())
  }

  @Test(arguments: ["en_US", "de_DE", "fr_FR"])
  func togglingEditedReviewAndReopeningPreserveTargets(localeID: String) throws {
    let locale = Locale(identifier: localeID)
    let expected = try plan(edited: true)
    let database = try store()
    let profile = try GoalSetupEditor.save(expected, replacing: nil, in: ModelContext(database))
    var draft = GoalSetupDraft.loaded(
      profile: profile, plan: expected, mass: .kilograms, length: .centimeters, locale: locale)
    #expect(draft.overridesEstimate)
    #expect(
      try draft.plan(mass: .kilograms, length: .centimeters, locale: locale).targets
        == expected.targets)
    // Starting a fresh estimate then enabling manual review must not introduce grouping.
    draft.overridesEstimate = false
    let estimated = try draft.plan(mass: .kilograms, length: .centimeters, locale: locale)
    draft.showEstimate(estimated, locale: locale)
    draft.overridesEstimate = true
    #expect(
      try draft.plan(mass: .kilograms, length: .centimeters, locale: locale).targets
        == estimated.targets)
  }

  @Test func switchingUnitsKeepsCanonicalValuesAndExplicitGoalChangesResetTargets() throws {
    let locale = Locale(identifier: "en_US")
    var draft = GoalSetupDraft()
    draft.age = "30"
    draft.coefficient = .plusFive
    draft.setHeight("180.123456789")
    draft.setWeight("80.123456789")
    draft.chooseGoal(.cut)
    draft.setTargetWeight("75.123456789")
    let original = try draft.plan(mass: .kilograms, length: .centimeters, locale: locale)
    for _ in 0..<5 {
      draft.changeMass(from: .kilograms, to: .pounds, locale: locale)
      draft.changeLength(from: .centimeters, to: .inches, locale: locale)
      draft.changeMass(from: .pounds, to: .kilograms, locale: locale)
      draft.changeLength(from: .inches, to: .centimeters, locale: locale)
    }
    let result = try draft.plan(mass: .kilograms, length: .centimeters, locale: locale)
    #expect(result.input == original.input)
    #expect(result.targetWeightKilograms == original.targetWeightKilograms)
    draft.chooseGoal(.bulk)
    #expect(draft.targetWeight.isEmpty)
    #expect(
      try draft.plan(mass: .kilograms, length: .centimeters, locale: locale).targetWeightKilograms
        == nil)
  }

  @Test func reopeningMaintenanceProvidesANonzeroRateForANewLossGoal() throws {
    let source = EnergyTargetInput(
      weightKilograms: 80, heightCentimeters: 180, ageYears: 30,
      coefficient: .plusFive, activityMultiplier: 1.2, weeklyWeightChangePercent: 0, goal: .maintain
    )
    let saved = try GoalSetupPlanner.make(input: source)
    var draft = GoalSetupDraft.loaded(
      profile: nil, plan: saved, mass: .kilograms, length: .centimeters,
      locale: Locale(identifier: "en_US"))
    draft.setHeight("180")
    draft.setWeight("80")
    draft.chooseGoal(.cut)
    #expect(draft.weeklyRate == 0.5)
    #expect(
      try draft.plan(mass: .kilograms, length: .centimeters, locale: Locale(identifier: "en_US"))
        .input.weeklyWeightChangePercent == 0.5)
  }
}
