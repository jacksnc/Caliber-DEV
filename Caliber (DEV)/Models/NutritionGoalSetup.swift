import CaliberCore
import Foundation
import SwiftData

/// An additive record for the guided setup. Existing UserProfile fields remain
/// the shared daily-target read model for Diary/Today and personal edits.
@Model
final class NutritionGoalSetup {
  var id: UUID
  var profileID: UUID
  var updatedAt: Date
  var planData: Data

  init(profileID: UUID, planData: Data, updatedAt: Date = .now) {
    id = UUID()
    self.profileID = profileID
    self.planData = planData
    self.updatedAt = updatedAt
  }

  var plan: GoalSetupPlan? { try? GoalSetupPlanner.decode(planData) }
}
