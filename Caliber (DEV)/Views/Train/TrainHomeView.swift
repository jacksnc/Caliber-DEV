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
          Section {
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
              .accessibilityIdentifier("resumeWorkout")
            } else {
              startCard(last: history.first)
            }
          } header: {
            CaliberHeader("Train", identifier: "Train").caliberSectionHeader()
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
                      .foregroundStyle(theme.palette.accent.base.color)
                      .frame(width: 40, height: 40)
                      .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                          .fill(theme.palette.accent.base.color.opacity(0.14))
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
      .contentMargins(.top, 0, for: .scrollContent)
      .listSectionSpacing(12)
      .caliberScreen()
      .compactNavigationTitle("Train")
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

  /// Look book: the session card names the last workout and lists its exercises, with
  /// "Repeat" filling a new session from what was logged then.
  private func startCard(last: TrainingWorkout?) -> some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
      HStack(spacing: HeliosTokens.space(3)) {
        Image(systemName: "dumbbell")
          .foregroundStyle(theme.palette.accent.base.color)
          .frame(width: 40, height: 40)
          .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(theme.palette.accent.base.color.opacity(0.14))
          )
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 2) {
          Text(last?.name ?? "Your first session").heliosFont(.section)
            .fixedSize(horizontal: false, vertical: true)
          Text(
            last.map {
              "Last time \($0.startedAt.formatted(.dateTime.weekday(.wide).month().day())) · \($0.completedSets.count) sets"
            } ?? "Add exercises as you go. Each set saves when you tick it."
          )
          .heliosFont(.footnote)
          .foregroundStyle(theme.palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      if let last {
        VStack(alignment: .leading, spacing: HeliosTokens.space(2)) {
          ForEach(last.sortedExercises) { row in
            HStack(alignment: .firstTextBaseline) {
              Text(row.exercise?.name ?? "Deleted exercise").heliosFont(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
              Text(summary(row)).heliosFont(.footnote)
                .foregroundStyle(theme.palette.text.secondary.color)
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
          }
        }
        Button {
          repeatWorkout(last)
        } label: {
          Label("Repeat \(last.name)", systemImage: "arrow.clockwise")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.heliosPrimary)
        .accessibilityIdentifier("repeatWorkout")
      }
      if last == nil {
        Button(action: startWorkout) {
          Label("Start Workout", systemImage: "plus").frame(maxWidth: .infinity)
        }
        .buttonStyle(.heliosPrimary)
        .accessibilityIdentifier("startWorkout")
      } else {
        Button(action: startWorkout) {
          Label("Empty workout", systemImage: "plus").frame(maxWidth: .infinity)
        }
        .buttonStyle(.heliosSecondary)
        .accessibilityIdentifier("startWorkout")
      }
    }
    .padding(.vertical, HeliosTokens.space(2))
  }

  /// "4 sets · top 200 lb × 6": finished working sets and the heaviest of them.
  private func summary(_ row: TrainingWorkoutExercise) -> String {
    let sets = row.sortedSets.filter { $0.completedAt != nil && !$0.isWarmup }
    guard
      let top = sets.max(by: {
        ($0.weightKilograms, $0.repetitions) < ($1.weightKilograms, $1.repetitions)
      })
    else { return "No sets" }
    let weight = top.enteredWeight.formatted(.number.precision(.fractionLength(0...1)))
    return
      "\(sets.count) \(sets.count == 1 ? "set" : "sets") · top \(weight) \(top.enteredWeightUnitRawValue) × \(top.repetitions)"
  }

  private func repeatWorkout(_ last: TrainingWorkout) {
    do {
      newWorkout = try TrainingWorkoutLogger.repeating(last, in: modelContext)
      showingNewWorkout = true
    } catch {
      message = "The workout could not be started. Your existing data was not changed."
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
    .toolbar(.visible, for: .navigationBar)
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
