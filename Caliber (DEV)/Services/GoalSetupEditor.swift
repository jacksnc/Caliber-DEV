import CaliberCore
import Foundation
import SwiftData

/// One explicit save updates both the setup and the values existing screens use.
/// No weigh-in, diary item, account or remote request is created by goal setup.
@MainActor
enum GoalSetupEditor {
  static func latest(for profileID: UUID, in context: ModelContext) throws -> NutritionGoalSetup? {
    let rows = try context.fetch(FetchDescriptor<NutritionGoalSetup>())
    return rows.filter { $0.profileID == profileID }.sorted {
      $0.updatedAt == $1.updatedAt
        ? $0.id.uuidString < $1.id.uuidString : $0.updatedAt > $1.updatedAt
    }.first
  }

  @discardableResult
  static func save(
    _ plan: GoalSetupPlan, replacing existing: UserProfile?, in context: ModelContext,
    now: Date = .now, commit: (() throws -> Void)? = nil
  ) throws -> UserProfile {
    let encoded = try GoalSetupPlanner.encode(plan)
    let activity = ActivityLevel.allCases.first {
      $0.activityMultiplier == plan.input.activityMultiplier
    }
    guard let activity else { throw EnergyTargetError.invalidActivityMultiplier }
    let targets = plan.targets
    let profile =
      existing
      ?? UserProfile(
        heightInInches: plan.input.heightCentimeters / 2.54,
        startingWeight: plan.input.weightKilograms / 0.45359237,
        activityLevel: activity, dailyCalorieGoal: targets.calories,
        proteinGoal: targets.protein, carbGoal: targets.carbohydrates, fatGoal: targets.fat)
    let previous = (
      profile.heightInInches, profile.startingWeight, profile.activityLevel,
      profile.dailyCalorieGoal, profile.proteinGoal, profile.carbGoal, profile.fatGoal
    )
    let priorSetup = try latest(for: profile.id, in: context)
    let setup =
      priorSetup
      ?? NutritionGoalSetup(
        profileID: profile.id, planData: encoded, updatedAt: now)
    let priorData = setup.planData
    let priorDate = setup.updatedAt
    if existing == nil { context.insert(profile) }
    if priorSetup == nil { context.insert(setup) }
    profile.heightInInches = plan.input.heightCentimeters / 2.54
    profile.startingWeight = plan.input.weightKilograms / 0.45359237
    profile.activityLevel = activity
    profile.dailyCalorieGoal = targets.calories
    profile.proteinGoal = targets.protein
    profile.carbGoal = targets.carbohydrates
    profile.fatGoal = targets.fat
    setup.planData = encoded
    setup.updatedAt = now
    do {
      if let commit { try commit() } else { try context.save() }
    } catch {
      // Restore only these edits; a global rollback could discard another log.
      if priorSetup == nil {
        context.delete(setup)
      } else {
        setup.planData = priorData
        setup.updatedAt = priorDate
      }
      if existing == nil {
        context.delete(profile)
      } else {
        profile.heightInInches = previous.0
        profile.startingWeight = previous.1
        profile.activityLevel = previous.2
        profile.dailyCalorieGoal = previous.3
        profile.proteinGoal = previous.4
        profile.carbGoal = previous.5
        profile.fatGoal = previous.6
      }
      throw error
    }
    return profile
  }
}
