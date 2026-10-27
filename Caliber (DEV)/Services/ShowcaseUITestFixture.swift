#if DEBUG
  import Foundation
  import SwiftData

  /// Fictional, filled-in data for the screenshot tests, so screens can be compared with the
  /// look book's populated boards. Used only with `--showcase-fixture` and the isolated
  /// in-memory test store. Every value is invented.
  @MainActor enum ShowcaseUITestFixture {
    static func seed(in context: ModelContext, now: Date, calendar: Calendar) throws {
      guard try context.fetchCount(FetchDescriptor<UserProfile>()) == 0 else { return }
      context.insert(
        UserProfile(
          heightInInches: 70, startingWeight: 184, activityLevel: .moderatelyActive,
          dailyCalorieGoal: 2350, proteinGoal: 180, carbGoal: 240, fatGoal: 70))

      // Today's meals add up to 1,462 kcal · 142 g protein · 118 g carbs · 52 g fat.
      let meals: [(String, MealType, Double, Double, Double, Double)] = [
        ("Fictional oats and berries", .breakfast, 420, 28, 52, 12),
        ("Fictional chicken bowl", .lunch, 650, 62, 48, 24),
        ("Fictional yogurt and nuts", .snack, 392, 52, 18, 16),
      ]
      for (name, meal, kcal, protein, carbs, fat) in meals {
        let food = FoodItem(
          name: name, calories: kcal, proteinGrams: protein, carbGrams: carbs, fatGrams: fat,
          servingDescription: "1 fictional serving")
        context.insert(food)
        context.insert(DiaryEntry(date: now, mealType: meal, foodItem: food))
      }

      // Thirty days of weigh-ins drifting gently down, with day-to-day noise.
      let today = calendar.startOfDay(for: now)
      let noise: [Double] = [0.6, -0.4, 0.2, 0.8, -0.2, 0.4, -0.6, 0.0, 0.5, -0.3]
      for day in stride(from: 30, through: 0, by: -1) {
        guard
          let date = calendar.date(byAdding: .hour, value: 7, to: today)
            .flatMap({ calendar.date(byAdding: .day, value: -day, to: $0) })
        else { continue }
        let pounds = 181.4 + Double(day) * 0.105 + noise[day % noise.count]
        context.insert(WeightEntry(date: date, weightInPounds: pounds))
      }

      // Yesterday's finished session, so Today and Train have a last workout to show.
      if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
        let started = calendar.date(byAdding: .hour, value: 18, to: yesterday)
      {
        let workout = TrainingWorkout(name: "Push A", startedAt: started)
        workout.completedAt = started.addingTimeInterval(55 * 60)
        context.insert(workout)
        let bench = TrainingExercise(name: "Bench Press", isCustom: false)
        context.insert(bench)
        let entry = TrainingWorkoutExercise(position: 0, exercise: bench)
        entry.workout = workout
        context.insert(entry)
        for index in 0..<4 {
          let set = TrainingWorkoutSet(position: index)
          set.enteredWeight = 200
          set.enteredWeightUnitRawValue = "lb"
          set.weightKilograms = 200 * 0.45359237
          set.repetitions = index == 3 ? 5 : 6
          set.completedAt = started.addingTimeInterval(Double(index + 1) * 240)
          set.workoutExercise = entry
          context.insert(set)
        }
      }
      try context.save()
    }
  }
#endif
