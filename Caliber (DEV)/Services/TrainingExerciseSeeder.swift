import SwiftData

@MainActor
enum TrainingExerciseSeeder {
  /// Small original starter set for the first Train slice. The licensed
  /// 600-exercise catalog remains a separate reviewed import.
  static func seedIfNeeded(in context: ModelContext) throws {
    guard try context.fetch(FetchDescriptor<TrainingExercise>()).allSatisfy(\.isCustom) else {
      return
    }

    // This first logger intentionally seeds only the metric its editor supports.
    // The remaining metric types are already represented in the model and will
    // be exposed as their dedicated set editors are added.
    let starterExercises: [(String, String, ExerciseMetricType)] = [
      ("Back Squat", "squat,barbell squat", .weightAndReps),
      ("Bench Press", "barbell bench,chest press", .weightAndReps),
      ("Deadlift", "conventional deadlift", .weightAndReps),
      ("Overhead Press", "shoulder press,military press", .weightAndReps),
      ("Barbell Row", "bent-over row", .weightAndReps),
      ("Dumbbell Curl", "biceps curl", .weightAndReps),
      ("Triceps Pushdown", "cable pushdown", .weightAndReps),
      ("Leg Press", "machine leg press", .weightAndReps),
      ("Lat Pulldown", "cable pulldown", .weightAndReps),
      ("Romanian Deadlift", "rdl", .weightAndReps),
      ("Hip Thrust", "barbell hip thrust", .weightAndReps),
      ("Lateral Raise", "side raise", .weightAndReps),
    ]
    for (name, aliases, metric) in starterExercises {
      context.insert(
        TrainingExercise(name: name, aliases: aliases, metricType: metric, isCustom: false))
    }
    try context.save()
  }
}
