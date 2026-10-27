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
  @Query(sort: \TrainingWorkout.startedAt, order: .reverse) private var allWorkouts:
    [TrainingWorkout]
  @Environment(\.heliosTheme) private var theme
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
        } header: {
          // Look book: elapsed time over the workout name, with the rest since the last set.
          TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(alignment: .top) {
              CaliberHeader(
                LocalizedStringKey(workout.name), identifier: "ActiveWorkout",
                overline: Text(
                  "\(duration(since: workout.startedAt, now: context.date)) · \(workout.completedSets.count) sets"
                ))
              if let rest = restSince(now: context.date) {
                Label("Rest \(rest)", systemImage: "timer")
                  .heliosFont(.footnote)
                  .padding(.horizontal, HeliosTokens.space(3))
                  .frame(minHeight: 36)
                  .background { GlassBackground(level: .raised, cornerRadius: 18) }
                  .accessibilityLabel("Rest \(rest)")
              }
            }
          }
          .caliberSectionHeader()
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

        if !workout.exercises.isEmpty {
          Button {
            showingFinishConfirmation = true
          } label: {
            Text("Finish workout").frame(maxWidth: .infinity)
          }
          .buttonStyle(.heliosSecondary)
          .disabled(workout.completedSets.isEmpty)
          .accessibilityIdentifier("finishWorkoutBottom")
          .caliberHeaderRow()
        }
      }
      .listRowBackground(CaliberRowBackground())
    }
    .caliberScreen()
    // The workout name is the header below; the bar keeps only its buttons.
    .compactNavigationTitle("Active Workout")
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

  /// Set · Previous · weight · Reps, as in the look book's set grid.
  @ViewBuilder private var columnHeader: some View {
    if !typeSize.isAccessibilitySize {
      HStack(spacing: 8) {
        Text("Set").frame(minWidth: 24, alignment: .leading)
        Text("Previous").frame(width: 64, alignment: .leading)
        Text(runtime.settings.massUnit.rawValue).frame(width: 76)
        Text("Reps").frame(width: 58)
        Spacer(minLength: 0)
      }
      .heliosFont(.caption)
      .foregroundStyle(theme.palette.text.secondary.color)
      .accessibilityHidden(true)
    }
  }

  /// The same exercise's working sets from the most recent finished workout, as "200 × 6".
  private func previousSets(for workoutExercise: TrainingWorkoutExercise) -> [String] {
    guard let exerciseID = workoutExercise.exercise?.id else { return [] }
    for past in allWorkouts where past.completedAt != nil && past.id != workout.id {
      guard
        let match = past.sortedExercises.first(where: { $0.exercise?.id == exerciseID })
      else { continue }
      return match.sortedSets.filter { $0.completedAt != nil }.map {
        "\($0.enteredWeight.formatted(.number.precision(.fractionLength(0...1)))) × \($0.repetitions)"
      }
    }
    return []
  }

  /// The heaviest finished working set of this exercise in earlier workouts, as logged
  /// ("200 lb × 6"); more repetitions break a tie. A record, not an estimate.
  private func bestSet(for workoutExercise: TrainingWorkoutExercise) -> String? {
    guard let exerciseID = workoutExercise.exercise?.id else { return nil }
    let sets =
      allWorkouts
      .filter { $0.completedAt != nil && $0.id != workout.id }
      .flatMap(\.sortedExercises)
      .filter { $0.exercise?.id == exerciseID }
      .flatMap(\.sortedSets)
      .filter { $0.completedAt != nil && !$0.isWarmup && $0.repetitions > 0 }
    guard
      let best = sets.max(by: {
        ($0.weightKilograms, $0.repetitions) < ($1.weightKilograms, $1.repetitions)
      })
    else { return nil }
    return
      "\(best.enteredWeight.formatted(.number.precision(.fractionLength(0...1)))) \(best.enteredWeightUnitRawValue) × \(best.repetitions)"
  }

  private func duration(since start: Date, now: Date) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(start)))
    return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
  }

  /// Time since the last completed set, shown for ten minutes after it.
  private func restSince(now: Date) -> String? {
    guard let last = workout.completedSets.compactMap(\.completedAt).max() else { return nil }
    let seconds = Int(now.timeIntervalSince(last))
    guard seconds >= 0, seconds < 600 else { return nil }
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
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
      let previous = previousSets(for: workoutExercise)
      // Look book: the exercise names its card, with a fact from history under it.
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 2) {
          Text(workoutExercise.exercise?.name ?? "Deleted exercise")
            .heliosFont(.section)
            .accessibilityAddTraits(.isHeader)
          if let best = bestSet(for: workoutExercise) {
            Text("Best set \(best)")
              .heliosFont(.footnote)
              .foregroundStyle(theme.palette.text.secondary.color)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Button(role: .destructive) {
          delete(workoutExercise)
        } label: {
          Image(systemName: "trash")
            .frame(minWidth: 48, minHeight: 48)
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.palette.text.secondary.color)
        .accessibilityLabel("Remove exercise")
      }
      columnHeader
      ForEach(workoutExercise.sortedSets) { set in
        TrainingSetRow(
          set: set, displayUnit: runtime.settings.massUnit,
          previous: previous.indices.contains(set.position) ? previous[set.position] : nil
        )
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
  let previous: String?
  @State private var weightText: String
  @State private var repetitionsText: String
  @State private var rpeText: String
  @State private var message: String?

  init(set: TrainingWorkoutSet, displayUnit: MassUnit, previous: String? = nil) {
    self.set = set
    self.displayUnit = displayUnit
    self.previous = previous
    _weightText = State(
      initialValue: set.weightKilograms == 0
        ? "" : String(format: "%g", displayUnit.fromKilograms(set.weightKilograms)))
    _repetitionsText = State(
      initialValue: set.repetitions == 0 ? "" : String(set.repetitions))
    _rpeText = State(initialValue: set.rpe.map { String(format: "%g", $0) } ?? "")
  }

  var body: some View {
    if set.completedAt != nil && !typeSize.isAccessibilitySize {
      // Look book: a finished set stays in the grid with a filled tick; tapping the tick
      // reopens it.
      HStack(spacing: 8) {
        setNumber
        Text(previous ?? "–")
          .heliosFont(.footnote)
          .foregroundStyle(theme.palette.text.secondary.color)
          .frame(width: 64, alignment: .leading)
          .accessibilityLabel(previous.map { "Previous \($0)" } ?? "No previous set")
        value(
          "\(set.enteredWeight.formatted(.number)) \(set.enteredWeightUnitRawValue)",
          shown: set.enteredWeight.formatted(.number), width: 76)
        value("\(set.repetitions) reps", shown: String(set.repetitions), width: 58)
        Spacer(minLength: 0)
        Button(action: reopen) {
          Image(systemName: "checkmark")
            .fontWeight(.semibold)
            .foregroundStyle(theme.palette.text.onAccent.color)
            .frame(minWidth: 48, minHeight: 48)
            .background(
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.palette.accent.base.color)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set \(set.position + 1) completed")
        .accessibilityHint("Reopens the set")
      }
      .alert(
        "Set",
        isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })
      ) {
        Button("OK", role: .cancel) { message = nil }
      } message: {
        Text(message ?? "Please try again.")
      }
    } else if set.completedAt != nil {
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
          Button("Undo", action: reopen)
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
            if !typeSize.isAccessibilitySize {
              Text(previous ?? "–")
                .heliosFont(.footnote)
                .foregroundStyle(theme.palette.text.secondary.color)
                .frame(width: 64, alignment: .leading)
                .accessibilityLabel(previous.map { "Previous \($0)" } ?? "No previous set")
            }
            field("Weight", text: $weightText, width: 76)
            // The grid header names the unit; at accessibility sizes rows stack, so repeat it.
            if typeSize.isAccessibilitySize {
              Text(displayUnit.rawValue).foregroundStyle(.secondary)
            }
            field("Reps", text: $repetitionsText, width: 58)
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
        // The look book's grid is Set · Previous · weight · Reps; RPE and warm-up sit below.
        (typeSize.isAccessibilitySize
          ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
          : AnyLayout(HStackLayout(spacing: 12))) {
            Toggle("Warm-up set", isOn: $set.isWarmup)
              .onChange(of: set.isWarmup) { _, _ in try? modelContext.save() }
            field("RPE", text: $rpeText, width: 58)
          }
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

  private func reopen() {
    do { try TrainingWorkoutLogger.undo(set, in: modelContext) } catch {
      message = "The completed set could not be reopened."
    }
  }

  /// A logged value in the grid, drawn like the entry field it replaced.
  private func value(_ label: String, shown: String, width: CGFloat) -> some View {
    Text(shown)
      .heliosFont(.bodyStrong)
      .fixedSize(horizontal: false, vertical: true)
      .frame(width: width)
      .frame(minHeight: 48)
      .background { GlassBackground(level: .raised, cornerRadius: 12) }
      .accessibilityLabel(label)
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
      .heliosFont(.bodyStrong)
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
