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
  @State private var showingRename = false
  @State private var draftName = ""
  @State private var message: String?
  @State private var expandedExerciseID: UUID?
  @State private var hasChosenExpansion = false
  @State private var showsSetOptions = false
  // A collapsed card must keep values the person has typed but not completed.
  @State private var setDrafts: [UUID: WorkoutSetDraft] = [:]
  @FocusState private var focusedSetField: String?

  private var volume: String {
    let unit = runtime.settings.massUnit
    let value = unit.fromKilograms(workout.volumeKilograms)
    return "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit.rawValue)"
  }

  var body: some View {
    List {
      Group {
        Section {
        } header: {
          // Look book: elapsed time, sets and volume over the workout name, with the rest
          // since the last set. The pencil renames the workout.
          TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(alignment: .top) {
              CaliberHeader(
                LocalizedStringKey(workout.name), identifier: "ActiveWorkout",
                overline: Text(
                  "\(duration(since: workout.startedAt, now: context.date)) · \(workout.completedSets.count) sets · \(volume)"
                ), showsProfile: false)
              Button {
                draftName = workout.name
                showingRename = true
              } label: {
                Image(systemName: "pencil")
                  .foregroundStyle(theme.palette.text.secondary.color)
                  .frame(width: 48, height: 48)
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityLabel("Rename workout")
              .accessibilityIdentifier("renameWorkout")
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
    .contentMargins(.top, 0, for: .scrollContent)
    .listSectionSpacing(12)
    .caliberScreen()
    .scrollDismissesKeyboard(.interactively)
    // The workout name is the header below; the bar keeps only its buttons.
    .compactNavigationTitle("Active Workout", hidesBar: false)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { focusedSetField = nil }
          .accessibilityIdentifier("workoutKeyboardDone")
      }
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
          let added = try TrainingWorkoutLogger.addExercise(exercise, to: workout, in: modelContext)
          expandedExerciseID = added.id
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
    .alert("Rename Workout", isPresented: $showingRename) {
      TextField("Workout name", text: $draftName)
        .accessibilityIdentifier("workoutNameField")
      Button("Cancel", role: .cancel) {}
      Button("Save") { rename() }
    }
  }

  /// Set · Previous · weight · Reps, as in the look book's set grid.
  @ViewBuilder private var columnHeader: some View {
    if !typeSize.isAccessibilitySize {
      HStack(spacing: 8) {
        Text("Set").frame(minWidth: 24, alignment: .leading)
        Text("Previous").fixedSize(horizontal: false, vertical: true)
          .frame(width: 64, alignment: .leading)
        Text(runtime.settings.massUnit.rawValue).frame(width: 76)
        Text("Reps").frame(width: 58)
        Spacer(minLength: 0)
      }
      .heliosFont(.caption)
      .frame(minHeight: 32)
      .foregroundStyle(theme.palette.text.secondary.color)
      .accessibilityHidden(true)
    }
  }

  /// The same exercise's working sets from the most recent finished workout, as "200 × 6".
  private func previousSets(for workoutExercise: TrainingWorkoutExercise) -> [String] {
    let sets =
      (try? TrainingWorkoutHistory.previousSets(for: workoutExercise, in: modelContext)) ?? []
    return sets.map {
      let value = runtime.settings.massUnit.fromKilograms($0.weightKilograms)
      return "\(value.formatted(.number.precision(.fractionLength(0...1)))) × \($0.repetitions)"
    }
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

  /// A blank name keeps the current one.
  private func rename() {
    let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, name != workout.name else { return }
    let previous = workout.name
    workout.name = name
    do { try modelContext.save() } catch {
      workout.name = previous
      message = "The workout name could not be saved."
    }
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

  private func draftBinding(for set: TrainingWorkoutSet) -> Binding<WorkoutSetDraft> {
    Binding {
      if let saved = setDrafts[set.id] { return saved }
      var draft = WorkoutSetDraft()
      draft.massUnit = runtime.settings.massUnit
      draft.weight =
        set.weightKilograms == 0
        ? ""
        : String(format: "%g", runtime.settings.massUnit.fromKilograms(set.weightKilograms))
      draft.repetitions = set.repetitions == 0 ? "" : String(set.repetitions)
      draft.effort = set.rpe.map { String(format: "%g", $0) } ?? ""
      return draft
    } set: {
      setDrafts[set.id] = $0
    }
  }

  // Built in its own function: inline, Xcode 16.4 cannot type-check this list and
  // reports a misleading ChartContentBuilder error (D108).
  @ViewBuilder private func exerciseSection(_ workoutExercise: TrainingWorkoutExercise) -> some View
  {
    let expanded =
      expandedExerciseID == workoutExercise.id
      || (!hasChosenExpansion && expandedExerciseID == nil
        && workout.sortedExercises.first?.id == workoutExercise.id)
    Section {
      let previous = previousSets(for: workoutExercise)
      HStack(alignment: .center, spacing: 8) {
        Button {
          hasChosenExpansion = true
          expandedExerciseID = expanded ? nil : workoutExercise.id
        } label: {
          HStack(spacing: 12) {
            if !expanded {
              Image(systemName: "dumbbell")
                .foregroundStyle(theme.palette.accent.base.color)
                .frame(width: 40, height: 40)
                .background(
                  theme.palette.accent.subtle.color, in: RoundedRectangle(cornerRadius: 12)
                )
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
              Text(workoutExercise.exercise?.name ?? "Deleted exercise")
                .heliosFont(.section)
                .foregroundStyle(theme.palette.text.primary.color)
                .fixedSize(horizontal: false, vertical: true)
              if let best = bestSet(for: workoutExercise) {
                Text("Best set \(best)").heliosFont(.footnote)
                  .foregroundStyle(theme.palette.text.secondary.color)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !expanded {
              Image(systemName: "chevron.right")
                .foregroundStyle(theme.palette.text.secondary.color)
                .accessibilityHidden(true)
            }
          }
          .frame(minHeight: 48)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(expanded ? "Expanded" : "Collapsed")
        .accessibilityHint("Shows or hides this exercise's sets")
        .accessibilityIdentifier("workoutExercise-" + workoutExercise.id.uuidString)
        Menu {
          Button("Remove exercise", role: .destructive) { delete(workoutExercise) }
        } label: {
          Image(systemName: "ellipsis").frame(width: 44, height: 44)
            .foregroundStyle(theme.palette.text.secondary.color)
        }
        .accessibilityLabel("Exercise actions")
      }
      .listRowSeparator(.hidden)
      .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 12))
      if expanded {
        columnHeader
          .listRowSeparator(.hidden)
          .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 2, trailing: 16))
        let nextSetID = workoutExercise.sortedSets.first { $0.completedAt == nil }?.id
        ForEach(workoutExercise.sortedSets) { set in
          TrainingSetRow(
            set: set, draft: draftBinding(for: set), focusedField: $focusedSetField,
            displayUnit: runtime.settings.massUnit,
            previous: previous.indices.contains(set.position) ? previous[set.position] : nil,
            isNext: set.id == nextSetID, showsOptions: showsSetOptions
          )
          .listRowSeparator(.hidden)
          .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
          .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", role: .destructive) { delete(set) }
          }
        }
        HStack {
          Button {
            do { _ = try TrainingWorkoutLogger.addSet(to: workoutExercise, in: modelContext) } catch
            { message = "The set could not be added." }
          } label: {
            Label("Add Set", systemImage: "plus").frame(minHeight: 48)
          }
          Spacer()
          Button {
            showsSetOptions.toggle()
          } label: {
            Label("Set options", systemImage: "slider.horizontal.3")
              .heliosFont(.footnote).frame(minHeight: 48)
          }
          .accessibilityValue(showsSetOptions ? "Shown" : "Hidden")
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.palette.accent.base.color)
        .listRowSeparator(.hidden)
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
  @Binding var draft: WorkoutSetDraft
  @FocusState.Binding var focusedField: String?
  let displayUnit: MassUnit
  let previous: String?
  /// Only the next open set shows its warm-up switch and RPE, keeping the grid as compact
  /// as the look book's.
  let isNext: Bool
  let showsOptions: Bool
  @State private var message: String?

  init(
    set: TrainingWorkoutSet, draft: Binding<WorkoutSetDraft>,
    focusedField: FocusState<String?>.Binding,
    displayUnit: MassUnit,
    previous: String?, isNext: Bool, showsOptions: Bool
  ) {
    self.set = set
    _draft = draft
    _focusedField = focusedField
    self.displayUnit = displayUnit
    self.previous = previous
    self.isNext = isNext
    self.showsOptions = showsOptions
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
              .heliosFont(.caption)
              .foregroundStyle(theme.palette.text.secondary.color)
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
            field("Weight", text: $draft.weight, width: 76)
            // The grid header names the unit; at accessibility sizes rows stack, so repeat it.
            if typeSize.isAccessibilitySize {
              Text(displayUnit.rawValue).heliosFont(.callout)
                .foregroundStyle(theme.palette.text.secondary.color)
            }
            field("Reps", text: $draft.repetitions, width: 58)
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
        // The look book's grid is Set · Previous · weight · Reps; RPE and warm-up sit below
        // the next set to do.
        if (isNext && showsOptions) || set.isWarmup || !draft.effort.isEmpty {
          (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))) {
              Toggle("Warm-up set", isOn: $set.isWarmup)
                .onChange(of: set.isWarmup) { _, _ in try? modelContext.save() }
              field("RPE", text: $draft.effort, width: 58)
            }
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
      .focused($focusedField, equals: set.id.uuidString + "." + label)
      .keyboardType(.decimalPad)
      .multilineTextAlignment(.center)
      .heliosFont(.bodyStrong)
      .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : width)
      .frame(minHeight: 48)
      .background { GlassBackground(level: .raised, cornerRadius: 12) }
      .overlay {
        if isNext {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(theme.palette.accent.base.color, lineWidth: 1.5)
            .allowsHitTesting(false)
        }
      }
      .accessibilityLabel(label)
  }

  private func complete() {
    do {
      try TrainingWorkoutLogger.complete(
        set, weightText: draft.weight.isEmpty ? "0" : draft.weight,
        repetitionsText: draft.repetitions, rpeText: draft.effort,
        unit: displayUnit, locale: locale, in: modelContext)
    } catch {
      message = error.localizedDescription
    }
  }
}

private struct ExercisePickerView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.heliosTheme) private var theme
  @Query(sort: \TrainingExercise.name) private var exercises: [TrainingExercise]
  @State private var searchText = ""
  @State private var showingCustomExercise = false
  @State private var createdExercise: TrainingExercise?
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
      List {
        if filtered.isEmpty {
          Button {
            showingCustomExercise = true
          } label: {
            Label(
              String(localized: "Create Custom Exercise", table: "CustomExercises"),
              systemImage: "plus"
            )
            .frame(minHeight: 48)
          }
          .accessibilityIdentifier("pickerCreateMissingExercise")
          .listRowBackground(CaliberRowBackground())
        }
        ForEach(filtered) { exercise in
          Button {
            onSelect(exercise)
            dismiss()
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              Text(exercise.name).foregroundStyle(.primary)
              Text(exercise.metricType.displayName)
                .heliosFont(.caption)
                .foregroundStyle(theme.palette.text.secondary.color)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
          }
          .accessibilityLabel(exercise.name)
          .accessibilityValue(exercise.metricType.displayName)
          .listRowBackground(CaliberRowBackground())
        }
      }
      .caliberScreen()
      .navigationTitle("Add Exercise")
      .searchable(text: $searchText)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .primaryAction) {
          Button {
            showingCustomExercise = true
          } label: {
            Label(
              String(localized: "Create Exercise", table: "CustomExercises"), systemImage: "plus")
          }
          .accessibilityIdentifier("pickerCreateExercise")
        }
      }
      .sheet(isPresented: $showingCustomExercise, onDismiss: addCreatedExercise) {
        CustomExerciseView(initialName: searchText) { createdExercise = $0 }
      }
    }
  }

  /// Wait for the creation sheet to close before closing its presenting picker.
  private func addCreatedExercise() {
    guard let exercise = createdExercise else { return }
    createdExercise = nil
    onSelect(exercise)
    dismiss()
  }
}
