import Foundation

/// Read-only progress for an already logged value and an explicitly saved goal.
/// Missing/invalid goals do not turn into zero, and display clamping never alters
/// calories, macros or targets in storage. This is not a target calculator.
struct DiaryNutritionMetric {
  let value: Double?
  let goal: Double?

  init(value: Double, goal: Double?) {
    self.value = value.isFinite && value >= 0 ? value : nil
    self.goal = goal.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
  }

  var progress: Double? {
    guard let value, let goal else { return nil }
    // Compare first to avoid overflowing the ratio for extreme legacy inputs.
    return value >= goal ? 1 : value / goal
  }

  var remaining: Double? {
    guard let value, let goal else { return nil }
    return max(0, goal - value)
  }

  var aboveGoal: Double? {
    guard let value, let goal else { return nil }
    return max(0, value - goal)
  }
}
