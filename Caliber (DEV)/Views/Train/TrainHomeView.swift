import CaliberCore
import HeliosDesign
import SwiftData
import SwiftUI

struct TrainHomeView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.heliosTheme) private var theme
  @EnvironmentObject private var runtime: FoundationRuntime
  @Query(sort: \TrainingWorkout.startedAt, order: .reverse) private var workouts: [TrainingWorkout]
  @State private var newWorkout: TrainingWorkout?
  @State private var showingNewWorkout = false
  @State private var message: String?

  private var activeWorkout: TrainingWorkout? { workouts.first(where: \.isActive) }
  private var history: [TrainingWorkout] { workouts.filter { !$0.isActive } }

  var body: some View {
    NavigationStack {
      List {
        Group {
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
              VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
                Text(history.first.map { "Last time: \($0.name)" } ?? "Your first session")
                  .heliosFont(.section)
                Text(
                  history.first.map {
                    "\($0.startedAt.formatted(.dateTime.weekday(.wide).month().day())) · \($0.completedSets.count) sets"
                  } ?? "Add exercises as you go. Each set saves when you tick it."
                )
                .heliosFont(.footnote)
                .foregroundStyle(theme.palette.text.secondary.color)
                Button(action: startWorkout) {
                  Label("Start Workout", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.heliosPrimary)
                .accessibilityIdentifier("startWorkout")
              }
              .padding(.vertical, HeliosTokens.space(2))
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
                  HStack(spacing: HeliosTokens.space(3)) {
                    Image(systemName: "dumbbell")
                      .foregroundStyle(theme.palette.data.training.color)
                      .frame(width: 40, height: 40)
                      .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                          .fill(theme.palette.data.training.color.opacity(0.14))
                      )
                      .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                      Text(workout.name).heliosFont(.bodyStrong)
                      Text(
                        "\(workout.startedAt.formatted(.dateTime.month().day())) · \(workout.completedSets.count) sets · \(volume(workout)) volume"
                      )
                      .heliosFont(.caption)
                      .foregroundStyle(theme.palette.text.secondary.color)
                    }
                  }
                  .frame(minHeight: 48, alignment: .leading)
                }
              }
            }
          }
        }
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen()
      .navigationTitle("Train")
      .profileAvatar()
      .task {
        do { try TrainingExerciseSeeder.seedIfNeeded(in: modelContext) } catch {
          message = "The starter exercise list could not be prepared."
        }
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

  private func volume(_ workout: TrainingWorkout) -> String {
    let unit = runtime.settings.massUnit
    let value = unit.fromKilograms(workout.volumeKilograms)
    return "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit.rawValue)"
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
      Group {
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
        ForEach(workout.sortedExercises) { row in exerciseSection(row) }
      }
      .listRowBackground(CaliberRowBackground())
    }
    .caliberScreen()
    .navigationTitle(workout.name)
    .navigationBarTitleDisplayMode(.inline)
  }

  // Built in its own function: inline, Xcode 16.4 cannot type-check this list and
  // reports a misleading ChartContentBuilder error (D108).
  @ViewBuilder private func exerciseSection(_ row: TrainingWorkoutExercise) -> some View {
    Section {
      ForEach(row.sortedSets.filter { $0.completedAt != nil }) { set in
        Text(
          "\(set.enteredWeight, format: .number) \(set.enteredWeightUnitRawValue) × \(set.repetitions)"
        )
      }
    } header: {
      Text(row.exercise?.name ?? "Deleted exercise")
    }
  }
}
