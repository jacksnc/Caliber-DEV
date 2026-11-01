//
//  DiaryView.swift
//  Caliber (DEV)
//

import CaliberCore
import Combine
import HeliosDesign
import SwiftData
import SwiftUI

/// Shows the selected day's food diary: a running total at the top, and each entry
/// grouped under its meal (breakfast/lunch/dinner/snack).
struct DiaryView: View {
  @Binding private var widgetRequest: CaliberWidgetRequest?
  let canHandleWidgetRequest: Bool
  @Environment(\.calendar) private var calendar
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \DiaryEntry.date) private var allEntries: [DiaryEntry]
  @Query private var profiles: [UserProfile]
  @Environment(\.heliosTheme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize

  @State private var selectedDate: Date = .now
  @State private var mealTypePresentingSheet: MealType?
  @State private var entryBeingEdited: DiaryEntry?
  @State private var copyRequest: DiaryCopyRequest?
  @State private var repeatedEntry: DiaryEntry?
  @State private var navigationPath = NavigationPath()

  init(
    widgetRequest: Binding<CaliberWidgetRequest?> = .constant(nil),
    canHandleWidgetRequest: Bool = true
  ) {
    _widgetRequest = widgetRequest
    self.canHandleWidgetRequest = canHandleWidgetRequest
  }

  private var selectedDayEntries: [DiaryEntry] {
    allEntries.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
  }

  private var dailyTotals: MacroTotals {
    MacroCalculator.totals(for: selectedDayEntries)
  }

  var body: some View {
    NavigationStack(path: $navigationPath) {
      List {
        Group {
          Section {
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
          } header: {
            CaliberHeader("Diary", identifier: "Fuel", overline: Text("Fuel"))
              .caliberSectionHeader()
          }
          Section {
            MacroTotalsSummaryView(totals: dailyTotals, profile: profiles.first, date: selectedDate)
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
      .navigationDestination(for: CaliberFuelDestination.self) { destination in
        CaliberFuelDestinationView(destination: destination)
      }
      .sheet(item: $mealTypePresentingSheet, onDismiss: applyWidgetRequest) { meal in
        NavigationStack { FoodSearchView(mealType: meal, date: selectedDate) }
      }
      .sheet(item: $copyRequest, onDismiss: applyWidgetRequest) { request in
        CopyDiaryView(request: request, calendar: calendar)
      }
      .sheet(item: $repeatedEntry, onDismiss: applyWidgetRequest) { entry in
        if let food = entry.foodItem {
          NavigationStack {
            SavedFoodDetailView(
              food: food, initialQuantity: entry.quantity, mealType: entry.mealType,
              date: selectedDate)
          }
        }
      }
      .sheet(item: $entryBeingEdited, onDismiss: applyWidgetRequest) { entry in
        EditDiaryEntryView(entry: entry)
      }
    }
    .onChange(of: widgetRequest, initial: true) { _, _ in applyWidgetRequest() }
    .onChange(of: canHandleWidgetRequest) { _, ready in
      if ready { applyWidgetRequest() }
    }
    .onChange(of: navigationPath.count) { _, depth in
      if depth <= 1 { applyWidgetRequest() }
    }
  }

  private func applyWidgetRequest() {
    guard canHandleWidgetRequest, let request = widgetRequest else { return }
    // A second Add tap must keep the current search/review and any typed values.
    if mealTypePresentingSheet != nil, request.destination == .addFood {
      widgetRequest = nil
      return
    }
    guard mealTypePresentingSheet == nil, entryBeingEdited == nil,
      copyRequest == nil, repeatedEntry == nil,
      navigationPath.count <= 1
    else { return }
    navigationPath = NavigationPath()
    selectedDate = .now
    widgetRequest = nil
    if request.destination == .addFood { mealTypePresentingSheet = .snack }
  }

  private var libraryLink: some View {
    NavigationLink(value: CaliberFuelDestination.library) {
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
          .foregroundStyle(theme.palette.text.secondary.color)
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
        HStack(alignment: .center, spacing: 8) {
          mealActionButton(meal, copy: true)
            .frame(width: 104)
          mealHeading(meal, entries: entries)
            .frame(maxWidth: .infinity)
          mealActionButton(meal, copy: false)
            .frame(width: 104)
        }
        VStack(spacing: 8) {
          mealHeading(meal, entries: entries)
            .frame(maxWidth: .infinity)
          mealActions(meal)
        }
      }
      .padding(.bottom, entries.isEmpty ? 0 : 8)
      .overlay(alignment: .bottom) {
        if !entries.isEmpty {
          Rectangle()
            .fill(theme.palette.border.hairline.color)
            .frame(height: 1)
            .padding(.horizontal, 8)
            .accessibilityHidden(true)
        }
      }
      .textCase(nil)
    }
  }

  private func mealHeading(_ meal: MealType, entries: [DiaryEntry]) -> some View {
    VStack(alignment: .center, spacing: 4) {
      Text(meal.displayName).heliosFont(.section)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)

      let foodCount = entries.count == 1 ? "1 food" : "\(entries.count) foods"
      let calories = NutritionInput.format(
        MacroCalculator.totals(for: entries).calories, locale: locale)
      Text("\(foodCount) · \(calories) cal")
        .heliosFont(.caption)
        .foregroundStyle(theme.palette.text.secondary.color)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .foregroundStyle(theme.palette.text.primary.color)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("diaryMealHeader-\(meal.rawValue)")
  }

  private func mealActions(_ meal: MealType) -> some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 8) {
        mealActionButton(meal, copy: true)
        Spacer(minLength: 8)
        mealActionButton(meal, copy: false)
      }
      VStack(spacing: 8) {
        mealActionButton(meal, copy: true, wide: true)
        mealActionButton(meal, copy: false, wide: true)
      }
    }
  }

  private func mealActionButton(_ meal: MealType, copy: Bool, wide: Bool = false) -> some View {
    let palette = theme.palette
    let shape = RoundedRectangle(cornerRadius: copy ? 12 : 24, style: .continuous)

    return Button {
      if copy {
        copyRequest = DiaryCopyRequest(date: selectedDate, meal: meal)
      } else {
        mealTypePresentingSheet = meal
      }
    } label: {
      Label(copy ? "Copy" : "Add food", systemImage: copy ? "doc.on.doc" : "plus")
        .labelStyle(.titleAndIcon)
        .heliosFont(.bodyStrong)
        .foregroundStyle(copy ? palette.text.primary.color : palette.text.onAccent.color)
        .padding(.horizontal, 12)
        .frame(minWidth: 48, maxWidth: wide ? .infinity : nil, minHeight: 48)
        .background {
          shape.fill(copy ? palette.glass.raised.color : palette.accent.base.color)
        }
        .overlay {
          if copy || palette.isHighContrast {
            shape.strokeBorder(
              copy ? palette.border.hairline.color : palette.border.strong.color,
              lineWidth: palette.isHighContrast ? 1.5 : 1)
          }
        }
        .contentShape(shape)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(copy ? "Copy \(meal.displayName)" : "Add to \(meal.displayName)")
    .accessibilityIdentifier(
      copy ? "diaryCopy-\(meal.rawValue)" : "diaryAdd-\(meal.rawValue)")
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

/// A new presentation of the existing stored totals. This never changes a saved
/// goal or replaces reported calories with a 4/4/9 macro estimate.
private struct MacroTotalsSummaryView: View {
  @EnvironmentObject private var healthEnergy: HealthEnergyModel
  @State private var goalTime = Date.now
  @Environment(\.locale) private var locale
  @Environment(\.heliosTheme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.caliberProfileAction) private var openProfile
  let totals: MacroTotals
  let profile: UserProfile?
  let date: Date

  @State private var selectedMetric: DiarySummaryMetric = .calories

  private var selectedNutrition: DiaryNutritionMetric {
    let base = selectedMetric.goal(in: profile)
    let now = max(goalTime, Date.now)
    let goal: Double?
    if selectedMetric == .calories, Calendar.current.isDate(date, inSameDayAs: now), let base {
      goal = healthEnergy.goal(base: base, at: now)?.total
    } else {
      goal = base
    }
    return DiaryNutritionMetric(value: selectedMetric.value(in: totals), goal: goal)
  }

  var body: some View {
    VStack(spacing: 16) {
      metricPanel
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { goalTime = $0 }
        .contentShape(Rectangle())
        .simultaneousGesture(metricSwipe)

      metricPicker

      HStack(spacing: 12) {
        pageButton(step: -1, label: "Previous nutrition metric", symbol: "chevron.left")
        Text(
          "\(selectedMetric.accessibilityName) · \(selectedMetric.index + 1) of \(DiarySummaryMetric.allCases.count)"
        )
        .heliosFont(.caption)
        .foregroundStyle(theme.palette.text.secondary.color)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
        pageButton(step: 1, label: "Next nutrition metric", symbol: "chevron.right")
      }

      Text("Swipe or choose a metric")
        .heliosFont(.caption)
        .foregroundStyle(theme.palette.text.secondary.color)
        .accessibilityHidden(true)
    }
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Daily nutrition summary")
    .accessibilityValue(
      "\(selectedMetric.accessibilityName), page \(selectedMetric.index + 1) of \(DiarySummaryMetric.allCases.count)"
    )
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: selectMetric(step: 1)
      case .decrement: selectMetric(step: -1)
      @unknown default: break
      }
    }
    .accessibilityAction(named: Text("Next nutrition metric")) { selectMetric(step: 1) }
    .accessibilityAction(named: Text("Previous nutrition metric")) { selectMetric(step: -1) }
  }

  private var metricPanel: some View {
    VStack(spacing: 10) {
      Text(selectedMetric.title)
        .heliosFont(.footnote)
        .foregroundStyle(theme.palette.text.secondary.color)

      if selectedNutrition.goal != nil && !typeSize.isAccessibilitySize {
        figure
          .padding(24)
          .frame(maxWidth: .infinity, minHeight: 210)
          .background {
            Circle().stroke(theme.palette.border.hairline.color, lineWidth: 4)
              .overlay {
                Circle().trim(from: 0, to: selectedNutrition.progress ?? 0)
                  .stroke(
                    selectedMetric.color(in: theme),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                  )
                  .rotationEffect(.degrees(-90))
              }
              .frame(width: 210, height: 210)
              .accessibilityHidden(true)
          }
      } else {
        // At AX sizes the value gets the full card width without a decorative ring.
        figure.frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? nil : 210)
      }

      goalSummary
      if selectedMetric == .calories,
        Calendar.current.isDate(date, inSameDayAs: max(goalTime, Date.now)),
        let profile
      {
        HealthEnergyGoalBreakdown(base: profile.dailyCalorieGoal)
      }
      Text("Food totals · activity is shown separately")
        .heliosFont(.caption)
        .foregroundStyle(theme.palette.text.secondary.color)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
  }

  private var goalSummary: some View {
    Group {
      if selectedNutrition.value == nil {
        Text("Review the logged nutrition values")
          .heliosFont(.footnote)
          .foregroundStyle(theme.palette.text.secondary.color)
      } else if let over = selectedNutrition.aboveGoal, over > 0 {
        balanceText(over, suffix: selectedMetric.aboveGoalLabel)
      } else if let left = selectedNutrition.remaining {
        balanceText(left, suffix: selectedMetric.remainingLabel)
      } else if let openProfile {
        Button("Set goals in Profile", action: openProfile)
          .buttonStyle(.heliosSecondary)
          .frame(minHeight: 48)
          .accessibilityIdentifier("diarySetGoals")
      } else {
        Text("No daily goal set")
          .heliosFont(.footnote)
          .foregroundStyle(theme.palette.text.secondary.color)
      }
    }
  }

  @ViewBuilder private var metricPicker: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 6) {
        ForEach(DiarySummaryMetric.allCases) { metric in metricButton(metric) }
      }
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
        ForEach(DiarySummaryMetric.allCases) { metric in metricButton(metric) }
      }
    }
  }

  private func metricButton(_ metric: DiarySummaryMetric) -> some View {
    let selected = selectedMetric == metric
    let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
    return Button {
      // The button is also the non-swipe alternative to changing card pages.
      selectedMetric = metric
    } label: {
      Text(metric.title)
        .heliosFont(selected ? .bodyStrong : .footnote)
        .foregroundStyle(
          selected ? theme.palette.text.primary.color : theme.palette.text.secondary.color
        )
        .fixedSize(horizontal: true, vertical: true)
        .frame(minWidth: 48, maxWidth: .infinity, minHeight: 48)
        .background {
          shape.fill(
            selected ? theme.palette.accent.subtle.color : theme.palette.glass.raised.color)
        }
        .overlay {
          shape.strokeBorder(
            selected ? theme.palette.accent.base.color : theme.palette.border.hairline.color,
            lineWidth: selected ? 1.5 : 1)
        }
        .contentShape(shape)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Show \(metric.accessibilityName)")
    .accessibilityValue(selected ? "Selected" : "")
    .accessibilityAddTraits(selected ? .isSelected : [])
    .accessibilityIdentifier("diaryMetric-\(metric.rawValue)")
  }

  private func pageButton(step: Int, label: String, symbol: String) -> some View {
    Button {
      selectMetric(step: step)
    } label: {
      Image(systemName: symbol)
        .frame(minWidth: 48, minHeight: 48)
        .background(theme.palette.glass.raised.color, in: Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
    .accessibilityIdentifier(step < 0 ? "diaryPreviousMetric" : "diaryNextMetric")
  }

  private var metricSwipe: some Gesture {
    DragGesture(minimumDistance: 28)
      .onEnded { gesture in
        let horizontal = gesture.translation.width
        let vertical = gesture.translation.height
        guard abs(horizontal) >= 44, abs(horizontal) > abs(vertical) * 1.25 else { return }
        // There is no sliding animation, so the page also respects Reduce Motion.
        selectMetric(step: horizontal < 0 ? 1 : -1)
      }
  }

  private func selectMetric(step: Int) {
    let count = DiarySummaryMetric.allCases.count
    let next = (selectedMetric.index + step + count) % count
    selectedMetric = DiarySummaryMetric.allCases[next]
  }

  private var figure: some View {
    VStack(spacing: 4) {
      Text(selectedNutrition.value.map { NutritionInput.format($0, locale: locale) } ?? "—")
        .heliosFont(.hero)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel(
          selectedNutrition.value.map {
            "\(NutritionInput.format($0, locale: locale)) \(selectedMetric.accessibilityUnit)"
          } ?? "\(selectedMetric.accessibilityName) unavailable"
        )
        .accessibilityIdentifier(
          selectedMetric == .calories
            ? "diaryCalories" : "diaryMetricValue-\(selectedMetric.rawValue)")
      if let goal = selectedNutrition.goal {
        Text(
          "of \(NutritionInput.format(goal, locale: locale)) \(selectedMetric.accessibilityUnit)"
        )
        .heliosFont(.footnote)
        .multilineTextAlignment(.center)
        .foregroundStyle(theme.palette.text.secondary.color)
      } else {
        Text(LocalizedStringKey("\(selectedMetric.accessibilityName) logged · no goal set"))
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
}

private enum DiarySummaryMetric: String, CaseIterable, Identifiable {
  case calories
  case protein
  case carbs
  case fat

  var id: String { rawValue }
  var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }
  var title: LocalizedStringKey { LocalizedStringKey(accessibilityName) }
  var accessibilityName: String { rawValue.capitalized }
  var accessibilityUnit: String {
    switch self {
    case .calories: "calories"
    case .protein: "grams protein"
    case .carbs: "grams carbohydrates"
    case .fat: "grams fat"
    }
  }
  var remainingLabel: LocalizedStringKey {
    switch self {
    case .calories: "calories remaining"
    case .protein: "grams protein remaining"
    case .carbs: "grams carbohydrates remaining"
    case .fat: "grams fat remaining"
    }
  }
  var aboveGoalLabel: LocalizedStringKey {
    switch self {
    case .calories: "calories above goal"
    case .protein: "grams protein above goal"
    case .carbs: "grams carbohydrates above goal"
    case .fat: "grams fat above goal"
    }
  }

  func value(in totals: MacroTotals) -> Double {
    switch self {
    case .calories: totals.calories
    case .protein: totals.protein
    case .carbs: totals.carbs
    case .fat: totals.fat
    }
  }

  func goal(in profile: UserProfile?) -> Double? {
    switch self {
    case .calories: profile?.dailyCalorieGoal
    case .protein: profile?.proteinGoal
    case .carbs: profile?.carbGoal
    case .fat: profile?.fatGoal
    }
  }

  func color(in theme: HeliosTheme) -> Color {
    switch self {
    case .calories: theme.palette.data.energy.color
    case .protein: theme.palette.data.protein.color
    case .carbs: theme.palette.data.carbs.color
    case .fat: theme.palette.data.fat.color
    }
  }
}

#Preview {
  DiaryView()
    .modelContainer(for: [FoodItem.self, DiaryEntry.self, UserProfile.self], inMemory: true)
}
