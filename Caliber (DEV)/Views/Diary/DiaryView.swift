//
//  DiaryView.swift
//  Caliber (DEV)
//

import HeliosDesign
import SwiftData
import SwiftUI

/// Shows the selected day's food diary: a running total at the top, and each entry
/// grouped under its meal (breakfast/lunch/dinner/snack).
struct DiaryView: View {
  @Environment(\.calendar) private var calendar
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \DiaryEntry.date) private var allEntries: [DiaryEntry]
  @Query private var profiles: [UserProfile]
  @Environment(\.heliosTheme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.verticalSizeClass) private var verticalSizeClass

  @State private var selectedDate: Date = .now
  @State private var mealTypePresentingSheet: MealType?
  @State private var entryBeingEdited: DiaryEntry?
  @State private var copyRequest: DiaryCopyRequest?
  @State private var repeatedEntry: DiaryEntry?
  /// Food Library is pushed by state, not a NavigationLink, so it survives a layout switch
  /// and the compact row gets no disclosure accessory or row-wide tap.
  @State private var showsFoodLibrary = false

  /// A short landscape phone: the date and library controls share one tight row so the
  /// energy figure starts on screen. Accessibility sizes keep the full-width layout.
  private var usesCompactHeader: Bool {
    verticalSizeClass == .compact && !typeSize.isAccessibilitySize
  }

  private var selectedDayEntries: [DiaryEntry] {
    allEntries.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
  }

  private var dailyTotals: MacroTotals {
    MacroCalculator.totals(for: selectedDayEntries)
  }

  var body: some View {
    NavigationStack {
      List {
        Group {
          Section {
            if usesCompactHeader {
              compactControls
            } else {
              dateControls
              ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                  libraryLink
                  copyDayButton
                }
                VStack(spacing: 8) {
                  libraryLink
                  copyDayButton
                }
              }
              .listRowSeparator(.hidden)
            }
          } header: {
            // The "Fuel" overline repeats the selected tab; a short screen keeps the title.
            CaliberHeader(
              "Diary", identifier: "Fuel", overline: usesCompactHeader ? nil : Text("Fuel")
            )
            .caliberSectionHeader()
          }
          Section {
            MacroTotalsSummaryView(totals: dailyTotals, profile: profiles.first)
          }
          Section {
            Button {
              // The existing Quick Log food route also starts in Snacks. The
              // review displays the selected destination before anything saves.
              mealTypePresentingSheet = .snack
            } label: {
              Label("Add food", systemImage: "plus")
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.heliosPrimary)
            .accessibilityIdentifier("diaryAddFood")
          }
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

          ForEach(MealType.allCases) { meal in mealSection(meal) }
        }
        .listRowBackground(theme.palette.opaque.base.color)
      }
      .listStyle(.insetGrouped)
      .contentMargins(.top, 0, for: .scrollContent)
      .listSectionSpacing(12)
      .caliberScreen()
      .compactNavigationTitle("Fuel")
      .profileAvatar()
      .navigationDestination(isPresented: $showsFoodLibrary) { FoodLibraryView() }
      .sheet(item: $mealTypePresentingSheet) { meal in
        NavigationStack { FoodSearchView(mealType: meal, date: selectedDate) }
      }
      .sheet(item: $copyRequest) { request in
        CopyDiaryView(request: request, calendar: calendar)
      }
      .sheet(item: $repeatedEntry) { entry in
        if let food = entry.foodItem {
          NavigationStack {
            SavedFoodDetailView(
              food: food, initialQuantity: entry.quantity, mealType: entry.mealType,
              date: selectedDate)
          }
        }
      }
      .sheet(item: $entryBeingEdited) { entry in
        EditDiaryEntryView(entry: entry)
      }
    }
  }

  /// Pushes through `showsFoodLibrary` in both layouts, so rotating while the library is
  /// open never removes the control that pushed it (which would pop the screen).
  private var libraryLink: some View {
    Button {
      showsFoodLibrary = true
    } label: {
      Label("Food Library", systemImage: "books.vertical")
        .frame(maxWidth: .infinity, minHeight: 48)
    }
    .buttonStyle(.heliosSecondary)
    .accessibilityIdentifier("openFoodLibrary")
  }

  private var copyDayButton: some View {
    Button {
      copyRequest = DiaryCopyRequest(date: selectedDate, meal: nil)
    } label: {
      Label("Copy a Day", systemImage: "doc.on.doc")
        .frame(maxWidth: .infinity, minHeight: 48)
    }
    .buttonStyle(.heliosSecondary)
    .accessibilityIdentifier("diaryCopyDay")
  }

  /// Compact height: one row when it fits, then two short rows, then the full-width stack.
  /// Every variant holds the same five controls with the same identifiers and labels.
  private var compactControls: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 8) {
        compactDateRow
        compactLibraryButton
        compactCopyDayButton
      }
      VStack(spacing: 8) {
        compactDateRow
        HStack(spacing: 8) {
          compactLibraryButton
          compactCopyDayButton
        }
      }
      VStack(spacing: 8) {
        datePicker
        HStack {
          dayButton(offset: -1)
          Spacer()
          dayButton(offset: 1)
        }
        compactLibraryButton
        compactCopyDayButton
      }
    }
    .listRowSeparator(.hidden)
    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
  }

  private var compactDateRow: some View {
    HStack(spacing: 0) {
      dayButton(offset: -1)
      datePicker
      dayButton(offset: 1)
    }
  }

  private var compactLibraryButton: some View {
    Button {
      showsFoodLibrary = true
    } label: {
      Label("Food Library", systemImage: "books.vertical").frame(maxWidth: .infinity)
    }
    .buttonStyle(DiaryCompactActionStyle())
    .accessibilityIdentifier("openFoodLibrary")
  }

  private var compactCopyDayButton: some View {
    Button {
      copyRequest = DiaryCopyRequest(date: selectedDate, meal: nil)
    } label: {
      Label("Copy a Day", systemImage: "doc.on.doc").frame(maxWidth: .infinity)
    }
    .buttonStyle(DiaryCompactActionStyle())
    .accessibilityIdentifier("diaryCopyDay")
  }

  private var datePicker: some View {
    DatePicker("Diary date", selection: $selectedDate, displayedComponents: .date)
      .labelsHidden()
      .frame(minHeight: 48)
      .accessibilityIdentifier("diaryDate")
  }

  private var dateControls: some View {
    ViewThatFits(in: .horizontal) {
      HStack {
        dayButton(offset: -1)
        datePicker.frame(maxWidth: .infinity)
        dayButton(offset: 1)
      }
      VStack(spacing: 8) {
        datePicker
        HStack {
          dayButton(offset: -1)
          Spacer()
          dayButton(offset: 1)
        }
      }
    }
    .listRowSeparator(.hidden)
  }

  private func dayButton(offset: Int) -> some View {
    Button {
      // Calendar-day movement preserves the local day across daylight-saving changes.
      if let date = calendar.date(byAdding: .day, value: offset, to: selectedDate) {
        selectedDate = date
      }
    } label: {
      Image(systemName: offset < 0 ? "chevron.left" : "chevron.right")
        .frame(minWidth: 48, minHeight: 48)
    }
    .buttonStyle(.borderless)
    .accessibilityLabel(offset < 0 ? "Previous diary day" : "Next diary day")
    .accessibilityIdentifier(offset < 0 ? "diaryPreviousDay" : "diaryNextDay")
  }

  private func delete(entries: [DiaryEntry], at offsets: IndexSet) {
    for index in offsets {
      modelContext.delete(entries[index])
    }
  }

  // Built in its own function: inline, Xcode 16.4 cannot type-check this list and
  // reports a misleading ChartContentBuilder error (D108).
  @ViewBuilder private func mealSection(_ meal: MealType) -> some View {
    let entries = selectedDayEntries.filter { $0.mealType == meal }
    Section {
      if entries.isEmpty {
        Text("No items yet")
          .foregroundStyle(.secondary)
      } else {
        ForEach(entries) { entry in
          Button {
            entryBeingEdited = entry
          } label: {
            DiaryEntryRow(entry: entry)
              .foregroundStyle(.primary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityHint("Edit this diary entry")
          .accessibilityIdentifier("diaryEntry-\(entry.id.uuidString)")
          .contextMenu {
            if entry.foodItem != nil {
              Button("Log Again") { repeatedEntry = entry }
              Button("Repeat This Meal") {
                copyRequest = DiaryCopyRequest(
                  date: selectedDate, meal: entry.mealType, sourceDate: selectedDate)
              }

            }
          }
        }
        .onDelete { offsets in
          delete(entries: entries, at: offsets)
        }
      }
    } header: {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .center, spacing: 12) {
          mealHeading(meal, entries: entries)
          Spacer(minLength: 8)
          mealActions(meal)
        }
        VStack(alignment: .leading, spacing: 8) {
          mealHeading(meal, entries: entries)
          mealActions(meal)
        }
      }
      .textCase(nil)
    }
  }

  private func mealHeading(_ meal: MealType, entries: [DiaryEntry]) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(meal.displayName).heliosFont(.section)
      if !entries.isEmpty {
        Text(
          "\(NutritionInput.format(MacroCalculator.totals(for: entries).calories, locale: locale)) cal"
        )
        .heliosFont(.caption)
      }
    }
    .foregroundStyle(theme.palette.text.primary.color)
    .fixedSize(horizontal: false, vertical: true)
  }

  private func mealActions(_ meal: MealType) -> some View {
    HStack(spacing: 8) {
      Button {
        copyRequest = DiaryCopyRequest(date: selectedDate, meal: meal)
      } label: {
        Image(systemName: "doc.on.doc").frame(minWidth: 48, minHeight: 48)
      }
      .accessibilityLabel("Copy \(meal.displayName)")
      .accessibilityIdentifier("diaryCopy-\(meal.rawValue)")
      Button {
        mealTypePresentingSheet = meal
      } label: {
        Image(systemName: "plus.circle.fill").frame(minWidth: 48, minHeight: 48)
      }
      .accessibilityLabel("Add to \(meal.displayName)")
      .accessibilityIdentifier("diaryAdd-\(meal.rawValue)")
    }
    .buttonStyle(.borderless)
  }

}

private struct DiaryEntryRow: View {
  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.heliosTheme) private var theme
  let entry: DiaryEntry

  var body: some View {
    Group {
      if typeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 8) {
          description
          amount
        }
      } else {
        HStack(alignment: .top, spacing: 16) {
          description.frame(maxWidth: .infinity, alignment: .leading)
          amount
        }
      }
    }
    .padding(.vertical, 6)
    .frame(minHeight: 48)
    .accessibilityElement(children: .combine)
  }

  private var description: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(entry.foodItem?.name ?? "Unknown food")
        .heliosFont(.bodyStrong)
        .fixedSize(horizontal: false, vertical: true)
      Text(
        "\(NutritionInput.format(entry.quantity, locale: locale)) × \(entry.foodItem?.servingDescription ?? "serving")"
      )
      .heliosFont(.caption)
      .foregroundStyle(theme.palette.text.secondary.color)
      Text(
        "P \(NutritionInput.format(entry.protein, locale: locale)) g · C \(NutritionInput.format(entry.carbs, locale: locale)) g · F \(NutritionInput.format(entry.fat, locale: locale)) g"
      )
      .heliosFont(.caption)
      .foregroundStyle(theme.palette.text.secondary.color)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var amount: some View {
    VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
      Text(NutritionInput.format(entry.calories, locale: locale)).heliosFont(.metricValue)
      Text("cal").heliosFont(.caption).foregroundStyle(theme.palette.text.secondary.color)
    }
  }
}

/// The secondary Helios button look for the compact-height row: same type, colours and
/// raised surface and a 48pt target, without the style's padding stacked on a 48pt label
/// (which made each button 72pt tall in landscape).
private struct DiaryCompactActionStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    DiaryCompactActionBody(configuration: configuration)
  }
}

private struct DiaryCompactActionBody: View {
  let configuration: ButtonStyle.Configuration
  @Environment(\.heliosTheme) private var theme
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: HeliosTokens.radius.button, style: .continuous)
    configuration.label
      .heliosFont(.bodyStrong)
      .foregroundStyle(theme.palette.text.primary.color)
      .multilineTextAlignment(.center)
      .padding(.horizontal, HeliosTokens.space(3))
      .padding(.vertical, HeliosTokens.space(1))
      .frame(minHeight: 48)
      .background {
        GlassBackground(
          level: configuration.isPressed ? .overlay : .raised,
          cornerRadius: HeliosTokens.radius.button)
      }
      .contentShape(shape)
      .opacity(isEnabled ? 1 : 0.45)
  }
}

/// A new presentation of the existing stored totals. This never changes a saved
/// goal or replaces reported calories with a 4/4/9 macro estimate.
private struct MacroTotalsSummaryView: View {
  @Environment(\.locale) private var locale
  @Environment(\.heliosTheme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.caliberProfileAction) private var openProfile
  let totals: MacroTotals
  let profile: UserProfile?

  private var energy: DiaryNutritionMetric {
    DiaryNutritionMetric(value: totals.calories, goal: profile?.dailyCalorieGoal)
  }

  var body: some View {
    VStack(spacing: 16) {
      Text("Energy consumed")
        .heliosFont(.footnote)
        .foregroundStyle(theme.palette.text.secondary.color)
      if energy.goal != nil && !typeSize.isAccessibilitySize {
        figure
          .padding(24)
          .frame(maxWidth: .infinity, minHeight: 210)
          .background {
            Circle().stroke(theme.palette.border.hairline.color, lineWidth: 4)
              .overlay {
                Circle().trim(from: 0, to: energy.progress ?? 0)
                  .stroke(
                    theme.palette.data.energy.color,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                  )
                  .rotationEffect(.degrees(-90))
              }
              .frame(width: 210, height: 210)
              .accessibilityHidden(true)
          }
      } else {
        // At AX sizes the text gets the full card width, with no decorative ring to constrain it.
        figure.frame(maxWidth: .infinity)
      }
      if energy.value == nil {
        Text("Review the logged nutrition values")
          .heliosFont(.footnote)
          .foregroundStyle(theme.palette.text.secondary.color)
      } else if let over = energy.aboveGoal, over > 0 {
        balanceText(over, suffix: "calories above goal")
      } else if let left = energy.remaining {
        balanceText(left, suffix: "calories remaining")
      } else if let openProfile {
        Button("Set goals in Profile", action: openProfile)
          .buttonStyle(.heliosSecondary)
          .frame(minHeight: 48)
          .accessibilityIdentifier("diarySetGoals")
      }
      LazyVGrid(
        columns: Array(
          repeating: GridItem(.flexible(), alignment: .top),
          count: typeSize.isAccessibilitySize ? 1 : 3),
        spacing: 16
      ) {
        macro(
          "Protein", value: totals.protein, goal: profile?.proteinGoal,
          color: theme.palette.data.protein.color)
        macro(
          "Carbs", value: totals.carbs, goal: profile?.carbGoal,
          color: theme.palette.data.carbs.color)
        macro("Fat", value: totals.fat, goal: profile?.fatGoal, color: theme.palette.data.fat.color)
      }
      Text("Food totals · activity is shown separately")
        .heliosFont(.caption)
        .foregroundStyle(theme.palette.text.secondary.color)
        .multilineTextAlignment(.center)
    }
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity)
  }

  private var figure: some View {
    VStack(spacing: 4) {
      Text(energy.value.map { NutritionInput.format($0, locale: locale) } ?? "—")
        .heliosFont(.hero)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        // Keep the existing precise accessibility label and automation identifier.
        .accessibilityLabel(
          energy.value.map { "\(NutritionInput.format($0, locale: locale)) calories" }
            ?? "Calories unavailable"
        )
        .accessibilityIdentifier("diaryCalories")
      if let goal = energy.goal {
        Text("of \(NutritionInput.format(goal, locale: locale)) calories")
          .heliosFont(.footnote)
          .multilineTextAlignment(.center)
          .foregroundStyle(theme.palette.text.secondary.color)
      } else {
        Text("calories logged · no goal set")
          .heliosFont(.footnote)
          .multilineTextAlignment(.center)
          .foregroundStyle(theme.palette.text.secondary.color)
      }
    }
  }

  private func balanceText(_ value: Double, suffix: LocalizedStringKey) -> some View {
    VStack(spacing: 2) {
      Text(NutritionInput.format(value, locale: locale)).heliosFont(.bodyStrong)
      Text(suffix).heliosFont(.caption)
    }
    .frame(maxWidth: .infinity)
    .padding(8)
    .background(theme.palette.accent.subtle.color, in: RoundedRectangle(cornerRadius: 14))
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("diaryEnergyBalance")
  }

  private func macro(_ title: LocalizedStringKey, value: Double, goal: Double?, color: Color)
    -> some View
  {
    let metric = DiaryNutritionMetric(value: value, goal: goal)
    return VStack(alignment: typeSize.isAccessibilitySize ? .leading : .center, spacing: 6) {
      Text(title).heliosFont(.caption).foregroundStyle(theme.palette.text.secondary.color)
      Text(metric.value.map { "\(NutritionInput.format($0, locale: locale)) g" } ?? "—")
        .heliosFont(.metricValue)
        .fixedSize(horizontal: false, vertical: true)
      if let progress = metric.progress, let goal = metric.goal {
        ProgressView(value: progress).tint(color).accessibilityHidden(true)
        Text("of \(NutritionInput.format(goal, locale: locale)) g")
          .heliosFont(.caption)
          .foregroundStyle(theme.palette.text.secondary.color)
      }
    }
    .frame(maxWidth: .infinity, alignment: typeSize.isAccessibilitySize ? .leading : .center)
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  DiaryView()
    .modelContainer(for: [FoodItem.self, DiaryEntry.self, UserProfile.self], inMemory: true)
}
