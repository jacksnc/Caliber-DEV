import CaliberCore
import SwiftUI

struct GoalSetupSummary: View {
  let plan: GoalSetupPlan
  let profile: UserProfile
  let mass: MassUnit

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(plan.input.goal.goalSetupName).font(.headline)
      Text(
        "\(profile.dailyCalorieGoal, format: .number.precision(.fractionLength(0...1))) kcal/day"
      )
      .font(.title2.weight(.semibold)).monospacedDigit()
      .accessibilityIdentifier("goalSetupSavedCalories")
      if let target = plan.targetWeightKilograms {
        Text(
          "Target: \(mass.fromKilograms(target), format: .number.precision(.fractionLength(0...2))) \(mass.rawValue)"
        )
        .accessibilityIdentifier("goalSetupSavedTargetWeight")
      }
      Text(
        "Based on your saved setup. This is a starting estimate; daily goals remain editable below."
      )
      .font(.footnote).foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .contain)
  }
}
