import CaliberCore
import HeliosDesign
import SwiftData
import SwiftUI

struct ActiveWorkoutView: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var runtime: FoundationRuntime
  @Bindable var workout: TrainingWorkout
  @State private var showingExercisePicker = false
  @State private var showingFinishConfirmation = false
  @State private var message: String?

  var body: some View {
    List {
      Group {
        Section {
          (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout())) {
              stat("Sets", value: String(workout.completedSets.count))
              Spacer()
              stat(
                "Volume",
                value:
                  "\(runtime.settings.massUnit.fromKilograms(workout.volumeKilograms).formatted(.number.precision(.fractionLength(0...1)))) \(runtime.settings.massUnit.rawValue)"
              )
            }
          TextField("Workout name", text: $workout.name)
            .onSubmit(saveWorkoutMetadata)
        }

        if workout.exercises.isEmpty {
          ContentUnavailableView {
            Label("Add Your First Exercise", systemImage: "figure.strengthtraining.traditional")
          } description: {
            Text(
              "Choose an exercise, then enter weight and reps. A set saves as soon as you tap the checkmark."
            )
          } actions: {
            Button("Add Exercise") { showingExercisePicker = true }
              .buttonStyle(.heliosPrimary)
          }
        }

        ForEach(workout.sortedExercises) { workoutExercise in exerciseSection(workoutExercise) }
      }
      .listRowBackground(CaliberRowBackground())
    }
    .caliberScreen()
    .navigationTitle("Active Workout")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Add Exercise") { showingExercisePicker = true }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button("Finish") { showingFinishConfirmation = true }
          .disabled(workout.completedSets.isEmpty)
          .accessibilityIdentifier("finishWorkout")
      }
    }
    .sheet(isPresented: $showingExercisePicker) {
      ExercisePickerView { exercise in
        do {
          _ = try TrainingWorkoutLogger.addExercise(exercise, to: workout, in: modelContext)
        } catch {
          message = "The exercise could not be added."
        }
      }
    }
    .confirmationDialog(
      "Finish this workout?", isPresented: $showingFinishConfirmation,
      titleVisibility: .visible
    ) {
      Button("Finish Workout") { finish() }
      Button("Keep Training", role: .cancel) {}
    } message: {
      Text("The workout will move to your history. Completed sets are already saved.")
    }
    .alert(
      "Workout",
      isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })
    ) {
      Button("OK", role: .cancel) { message = nil }
    } message: {
      Text(message ?? "Please try again.")
    }
  }

  private func stat(_ label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value).font(.title3.bold()).monospacedDigit()
      Text(label).font(.caption).foregroundStyle(.secondary)
    }
  }

  private func saveWorkoutMetadata() {
    do { try modelContext.save() } catch { message = "The workout name could not be saved." }
  }

  private func delete(_ set: TrainingWorkoutSet) {
    modelContext.delete(set)
    do { try modelContext.save() } catch {
      modelContext.rollback()
      message = "The set could not be deleted."
    }
  }

  private func delete(_ exercise: TrainingWorkoutExercise) {
    modelContext.delete(exercise)
    do { try modelContext.save() } catch {
      modelContext.rollback()
      message = "The exercise could not be removed."
    }
  }

  private func finish() {
    do {
      try TrainingWorkoutLogger.finish(workout, in: modelContext)
      dismiss()
    } catch {
      message = "The workout could not be finished. Your completed sets are still saved."
    }
  }

  // Built in its own function: inline, Xcode 16.4 cannot type-check this list and
  // reports a misleading ChartContentBuilder error (D108).
  @ViewBuilder private func exerciseSection(_ workoutExercise: TrainingWorkoutExercise) -> some View
  {
    Section {
      ForEach(workoutExercise.sortedSets) { set in
        TrainingSetRow(set: set, displayUnit: runtime.settings.massUnit)
          .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", role: .destructive) { delete(set) }
          }
      }
      Button {
        do {
          _ = try TrainingWorkoutLogger.addSet(to: workoutExercise, in: modelContext)
        } catch { message = "The set could not be added." }
      } label: {
        Label("Add Set", systemImage: "plus")
          .frame(minHeight: 48)
      }
    } header: {
      HStack {
        Text(workoutExercise.exercise?.name ?? "Deleted exercise")
        Spacer()
        Button(role: .destructive) {
          delete(workoutExercise)
        } label: {
          Image(systemName: "trash")
            .frame(minWidth: 48, minHeight: 48)
        }
        .accessibilityLabel("Remove exercise")
      }
    }
  }
}

private struct TrainingSetRow: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.heliosTheme) private var theme
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var modelContext
  @Bindable var set: TrainingWorkoutSet
  let displayUnit: MassUnit
  @State private var weightText: String
  @State private var repetitionsText: String
  @State private var rpeText: String
  @State private var message: String?

  init(set: TrainingWorkoutSet, displayUnit: MassUnit) {
    self.set = set
    self.displayUnit = displayUnit
    _weightText = State(
      initialValue: set.weightKilograms == 0
        ? "" : String(format: "%g", displayUnit.fromKilograms(set.weightKilograms)))
    _repetitionsText = State(
      initialValue: set.repetitions == 0 ? "" : String(set.repetitions))
    _rpeText = State(initialValue: set.rpe.map { String(format: "%g", $0) } ?? "")
  }

  var body: some View {
    if set.completedAt != nil {
      (typeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
        : AnyLayout(HStackLayout(spacing: 12))) {
          setNumber
          VStack(alignment: .leading, spacing: 3) {
            Text(
              "\(set.enteredWeight, format: .number) \(set.enteredWeightUnitRawValue) × \(set.repetitions)"
            )
            .heliosFont(.metricValue)
            Text(set.isWarmup ? "Warm-up" : rpeSummary)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          // Look book: a completed set keeps a filled check in the accent colour.
          Image(systemName: "checkmark")
            .fontWeight(.semibold)
            .foregroundStyle(theme.palette.text.onAccent.color)
            .frame(width: 44, height: 44)
            .background(
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.palette.accent.base.color)
            )
            .accessibilityLabel("Completed")
          Button("Undo") {
            do { try TrainingWorkoutLogger.undo(set, in: modelContext) } catch {
              message = "The completed set could not be reopened."
            }
          }
          .frame(minHeight: 48)
        }
        .alert(
          "Set",
          isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })
        ) {
          Button("OK", role: .cancel) { message = nil }
        } message: {
          Text(message ?? "Please try again.")
        }
    } else {
      VStack(alignment: .leading, spacing: 10) {
        (typeSize.isAccessibilitySize
          ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
          : AnyLayout(HStackLayout(spacing: 8))) {
            setNumber
            field("Weight", text: $weightText, width: 82)
            Text(displayUnit.rawValue).foregroundStyle(.secondary)
            field("Reps", text: $repetitionsText, width: 58)
            field("RPE", text: $rpeText, width: 58)
            Spacer(minLength: 0)
            Button(action: complete) {
              Image(systemName: "checkmark")
                .fontWeight(.semibold)
                .foregroundStyle(theme.palette.text.secondary.color)
                .frame(minWidth: 48, minHeight: 48)
                .background {
                  GlassBackground(level: .raised, cornerRadius: 12)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Complete set \(set.position + 1)")
          }
        Toggle("Warm-up set", isOn: $set.isWarmup)
          .onChange(of: set.isWarmup) { _, _ in try? modelContext.save() }
      }
      .alert(
        "Check This Set",
        isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })
      ) {
        Button("OK", role: .cancel) { message = nil }
      } message: {
        Text(message ?? "Please check the values.")
      }
    }
  }

  private var setNumber: some View {
    Text("\(set.position + 1)")
      .heliosFont(.bodyStrong)
      .foregroundStyle(theme.palette.text.secondary.color)
      .frame(minWidth: 24, alignment: .leading)
      .accessibilityLabel("Set \(set.position + 1)")
  }

  private var rpeSummary: String {
    self.set.rpe.map { "Working set · RPE \($0.formatted(.number))" } ?? "Working set"
  }

  private func field(
    _ label: String, text: Binding<String>, width: CGFloat
  ) -> some View {
    TextField(label, text: text)
      .keyboardType(.decimalPad)
      .multilineTextAlignment(.center)
      .heliosFont(.metricValue)
      .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : width)
      .frame(minHeight: 48)
      .background { GlassBackground(level: .raised, cornerRadius: 12) }
      .accessibilityLabel(label)
  }

  private func complete() {
    do {
      try TrainingWorkoutLogger.complete(
        set, weightText: weightText.isEmpty ? "0" : weightText,
        repetitionsText: repetitionsText, rpeText: rpeText,
        unit: displayUnit, locale: locale, in: modelContext)
    } catch {
      message = error.localizedDescription
    }
  }
}

private struct ExercisePickerView: View {
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \TrainingExercise.name) private var exercises: [TrainingExercise]
  @State private var searchText = ""
  let onSelect: (TrainingExercise) -> Void

  private var filtered: [TrainingExercise] {
    let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    return term.isEmpty
      ? exercises
      : exercises.filter {
        $0.name.localizedStandardContains(term) || $0.aliases.localizedStandardContains(term)
      }
  }

  var body: some View {
    NavigationStack {
      List(filtered) { exercise in
        Button {
          onSelect(exercise)
          dismiss()
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name).foregroundStyle(.primary)
            Text(exercise.metricType.displayName)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        }
        .accessibilityLabel(exercise.name)
        .accessibilityValue(exercise.metricType.displayName)
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen()
      .navigationTitle("Add Exercise")
      .searchable(text: $searchText)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
      }
    }
  }
}
