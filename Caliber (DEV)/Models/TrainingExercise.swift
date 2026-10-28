import CaliberCore
import Foundation
import SwiftData

enum ExerciseMetricType: String, Codable, CaseIterable, Identifiable {
  case weightAndReps
  case bodyweightAndReps
  case weightedBodyweight
  case assistedBodyweight
  case repsOnly
  case duration
  case weightAndDuration
  case distance
  case distanceAndDuration

  var id: String { rawValue }

  var coreMetric: WorkoutMetric { WorkoutMetric(rawValue: rawValue)! }

  var displayName: String {
    switch self {
    case .weightAndReps: "Weight × reps"
    case .bodyweightAndReps: "Bodyweight × reps"
    case .weightedBodyweight: "Bodyweight + added weight"
    case .assistedBodyweight: "Bodyweight − assistance"
    case .repsOnly: "Reps only"
    case .duration: "Duration"
    case .weightAndDuration: "Weight × duration"
    case .distance: "Distance"
    case .distanceAndDuration: "Distance × duration"
    }
  }
}

/// A local exercise. Bundled starter rows contain only original names and
/// metadata; users can add unlimited custom exercises without an account.
@Model
final class TrainingExercise {
  var id: UUID
  var name: String
  var aliases: String
  var metricTypeRawValue: String
  var isCustom: Bool
  var isFavorite: Bool
  var defaultRestSeconds: Double? = nil
  var createdAt: Date

  @Relationship(deleteRule: .nullify, inverse: \TrainingWorkoutExercise.exercise)
  var workoutExercises: [TrainingWorkoutExercise] = []

  init(
    name: String, aliases: String = "", metricType: ExerciseMetricType = .weightAndReps,
    isCustom: Bool = true, isFavorite: Bool = false, createdAt: Date = .now
  ) {
    id = UUID()
    self.name = name
    self.aliases = aliases
    metricTypeRawValue = metricType.rawValue
    self.isCustom = isCustom
    self.isFavorite = isFavorite
    self.createdAt = createdAt
  }

  var metricType: ExerciseMetricType {
    get { ExerciseMetricType(rawValue: metricTypeRawValue) ?? .weightAndReps }
    set { metricTypeRawValue = newValue.rawValue }
  }
}
