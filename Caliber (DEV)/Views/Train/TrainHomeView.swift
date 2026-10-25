import SwiftData
import SwiftUI

struct TrainHomeView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \TrainingWorkout.startedAt, order: .reverse) private var workouts: [TrainingWorkout]
  @State private var newWorkout: TrainingWorkout?
  @State private var showingNewWorkout = false
  @State private var message: String?

  private var activeWorkout: TrainingWorkout? { workouts.first(where: \.isActive) }
  private var history: [TrainingWorkout] { workouts.filter { !$0.isActive } }

  var body: some View {
    NavigationStack {
      List {
        Section("Workout") {
          if let activeWorkout {
            NavigationLink {
              ActiveWorkoutView(workout: activeWorkout)
            } label: {
              VStack(alignment: .leading, spacing: 4) {
                Label("Resume Workout", systemImage: "play.fill")
                  .font(.headline)
                Text(
                  "\(activeWorkout.completedSets.count) completed sets · started \(activeWorkout.startedAt.formatted(date: .omitted, time: .shortened))"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
              }
              .frame(minHeight: 48, alignment: .leading)
            }
          } else {
            Button(action: startWorkout) {
              Label("Start Empty Workout", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            }
            .accessibilityIdentifier("startWorkout")
          }
        }

        Section("Library") {
          NavigationLink {
            ExerciseLibraryView()
          } label: {
            Label("Exercises", systemImage: "figure.strengthtraining.traditional")
              .frame(minHeight: 48)
          }
        }

        Section("History") {
          if history.isEmpty {
            Text("Finished workouts will appear here.")
              .foregroundStyle(.secondary)
          } else {
            ForEach(history.prefix(20)) { workout in
              NavigationLink {
                WorkoutSummaryView(workout: workout)
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Text(workout.name)
                  Text(
                    "\(workout.completedSets.count) sets · \(workout.volumeKilograms.formatted(.number.precision(.fractionLength(0...1)))) kg volume"
                  )
                  .font(.caption)
                  .foregroundStyle(.secondary)
                }
                .frame(minHeight: 48, alignment: .leading)
              }
            }
          }
        }
      }
      .navigationTitle("Train")
      .task {
        do { try TrainingExerciseSeeder.seedIfNeeded(in: modelContext) }
        catch { message = "The starter exercise list could not be prepared." }
      }
      .navigationDestination(isPresented: $showingNewWorkout) {
        if let newWorkout { ActiveWorkoutView(workout: newWorkout) }
      }
      .alert(
        "Train",
        isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })
      ) {
        Button("OK", role: .cancel) { message = nil }
      } message: {
        Text(message ?? "Please try again.")
      }
    }
  }

  private func startWorkout() {
    do {
      newWorkout = try TrainingWorkoutLogger.start(in: modelContext)
      showingNewWorkout = true
    } catch {
      message = "The workout could not be started. Your existing data was not changed."
    }
  }
}

private struct WorkoutSummaryView: View {
  let workout: TrainingWorkout

  var body: some View {
    List {
      Section("Summary") {
        LabeledContent("Completed sets", value: String(workout.completedSets.count))
        LabeledContent(
          "Volume",
          value:
            "\(workout.volumeKilograms.formatted(.number.precision(.fractionLength(0...1)))) kg")
        if let completedAt = workout.completedAt {
          LabeledContent(
            "Duration",
            value: Duration.seconds(completedAt.timeIntervalSince(workout.startedAt)).formatted())
        }
      }
      ForEach(workout.sortedExercises) { row in
        Section(row.exercise?.name ?? "Deleted exercise") {
          ForEach(row.sortedSets.filter { $0.completedAt != nil }) { set in
            Text(
              "\(set.enteredWeight, format: .number) \(set.enteredWeightUnitRawValue) × \(set.repetitions)"
            )
          }
        }
      }
    }
    .navigationTitle(workout.name)
    .navigationBarTitleDisplayMode(.inline)
  }
}
