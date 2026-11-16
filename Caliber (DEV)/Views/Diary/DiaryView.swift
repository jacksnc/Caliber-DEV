//
//  DiaryView.swift
//  Caliber (DEV)
//

import CaliberCore
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

  @State private var selectedDate: Date = .now
  @State private var mealTypePresentingSheet: MealType?
  @State private var entryBeingEdited: DiaryEntry?
  @State private var copyRequest: DiaryCopyRequest?
  @State private var repeatedEntry: DiaryEntry?

  private var selectedDayEntries: [DiaryEntry] {
    allEntries.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
  }

  private var dailyTotals: MacroTotals {
    MacroCalculator.totals(for: selectedDayEntries)
  }

  /// Days with at least one diary entry, for the week strip's dots.
  private var loggedDays: Set<Date> {
    Set(allEntries.map { calendar.startOfDay(for: $0.date) })
  }

  var body: some View {
    NavigationStack {
      List {
        Group {
          Section {
            DiaryWeekStrip(
              selection: $selectedDate, loggedDays: loggedDays, calendar: calendar)
            HStack {
              DatePicker("Diary date", selection: $selectedDate, displayedComponents: .date)
                .accessibilityIdentifier("diaryDate")
              Button {
                copyRequest = DiaryCopyRequest(date: selectedDate, meal: nil)
              } label: {
                Image(systemName: "doc.on.doc").frame(minWidth: 48, minHeight: 48)
              }
              .buttonStyle(.borderless)
              .accessibilityLabel("Copy a Day")
              .accessibilityIdentifier("diaryCopyDay")
            }
          } header: {
            CaliberHeader("Fuel", identifier: "Fuel", overline: Text("Diary"))
              .caliberSectionHeader()
          }
          Section {
            MacroTotalsSummaryView(
              totals: dailyTotals, profile: profiles.first,
              isToday: calendar.isDateInToday(selectedDate))
          }

          ForEach(MealType.allCases) { meal in mealSection(meal) }
        }
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen()
      .compactNavigationTitle("Fuel")
      .profileAvatar()
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          NavigationLink {
            FoodLibraryView()
          } label: {
            Label("Food Library", systemImage: "books.vertical")
          }
          .accessibilityIdentifier("openFoodLibrary")
        }
      }
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
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 0) {
          Text(meal.displayName).heliosFont(.section).textCase(nil)
          if !entries.isEmpty {
            Text(
              "\(NutritionInput.format(MacroCalculator.totals(for: entries).calories, locale: locale)) kcal"
            )
            .heliosFont(.caption).textCase(nil)
          }
        }
        Spacer()
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
          Image(systemName: "plus.circle").frame(minWidth: 48, minHeight: 48)
        }.accessibilityLabel("Add to \(meal.displayName)")
          .accessibilityIdentifier("diaryAdd-\(meal.rawValue)")
      }
    }
  }
}

private struct DiaryEntryRow: View {
  @Environment(\.locale) private var locale
  let entry: DiaryEntry

  var body: some View {
    VStack(alignment: .leading) {
      Text(entry.foodItem?.name ?? "Unknown food")
      Text(
        "\(NutritionInput.format(entry.calories, locale: locale)) kcal · P \(NutritionInput.format(entry.protein, locale: locale)) · C \(NutritionInput.format(entry.carbs, locale: locale)) · F \(NutritionInput.format(entry.fat, locale: locale))"
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      .accessibilityLabel(
        "\(NutritionInput.format(entry.calories, locale: locale)) kilocalories, protein \(NutritionInput.format(entry.protein, locale: locale)) grams, carbs \(NutritionInput.format(entry.carbs, locale: locale)) grams, fat \(NutritionInput.format(entry.fat, locale: locale)) grams"
      )
    }
  }
}

/// The week around the selected day. A dot marks a day with food logged; a day without a dot
/// simply has no entries and is never drawn as a miss.
private struct DiaryWeekStrip: View {
  @Binding var selection: Date
  let loggedDays: Set<Date>
  let calendar: Calendar
  @Environment(\.heliosTheme) private var theme

  private var days: [Date] {
    guard let week = calendar.dateInterval(of: .weekOfYear, for: selection) else { return [] }
    return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
  }

  var body: some View {
    // Seven days need a row each of at least 44 points; larger text keeps the date picker
    // below as the only control instead of squeezing the days.
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 2) {
        arrow("chevron.left", label: "Previous week", by: -7)
        ForEach(days, id: \.self) { day in dayButton(day).fixedSize() }
        arrow("chevron.right", label: "Next week", by: 7)
      }
      .frame(maxWidth: .infinity)
      EmptyView()
    }
    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
  }

  private func arrow(_ symbol: String, label: LocalizedStringKey, by days: Int) -> some View {
    Button {
      if let moved = calendar.date(byAdding: .day, value: days, to: selection) {
        selection = moved
      }
    } label: {
      Image(systemName: symbol)
        .font(.footnote.weight(.semibold))
        .frame(minWidth: 24, minHeight: 48)
        .contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .accessibilityLabel(label)
  }

  private func dayButton(_ day: Date) -> some View {
    let isSelected = calendar.isDate(day, inSameDayAs: selection)
    let isLogged = loggedDays.contains(calendar.startOfDay(for: day))
    return Button {
      selection = day
    } label: {
      VStack(spacing: 2) {
        Text(day, format: .dateTime.weekday(.narrow))
          .heliosFont(.caption)
          .foregroundStyle(theme.palette.text.secondary.color)
        Text(day, format: .dateTime.day())
          .heliosFont(.bodyStrong)
          .foregroundStyle(
            isSelected ? theme.palette.accent.base.color : theme.palette.text.primary.color)
        Circle()
          .fill(isLogged ? theme.palette.data.energy.color : .clear)
          .frame(width: 5, height: 5)
      }
      .frame(minWidth: 34, minHeight: 48)
      .padding(.vertical, 4)
      .background {
        if isSelected {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(theme.palette.accent.subtle.color)
        }
      }
      .overlay {
        if calendar.isDateInToday(day) && !isSelected {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(theme.palette.border.strong.color, lineWidth: 1)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .accessibilityLabel(
      Text(
        "\(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))\(isLogged ? ", food logged" : "")"
      )
    )
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    .accessibilityIdentifier("diaryDay-\(calendar.component(.weekday, from: day))")
  }
}

private struct MacroTotalsSummaryView: View {
  @Environment(\.locale) private var locale
  @Environment(\.heliosTheme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  let totals: MacroTotals
  let profile: UserProfile?
  let isToday: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: HeliosTokens.space(3)) {
        // Rings show each macro's share of the day's calories, as on Today and Progress.
        MacroRings(
          rings: [
            (progress: share(totals.protein * 4), color: theme.palette.data.protein.color),
            (progress: share(totals.carbs * 4), color: theme.palette.data.carbs.color),
            (progress: share(totals.fat * 9), color: theme.palette.data.fat.color),
          ], lineWidth: 6, gap: 2
        ) { EmptyView() }
        .frame(width: 52, height: 52)
        .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 2) {
          // The total is shown exactly as logged; the label keeps its spoken form.
          Text("\(NutritionInput.format(totals.calories, locale: locale)) kcal")
            .heliosFont(.metricValue)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(
              "\(NutritionInput.format(totals.calories, locale: locale)) calories"
            )
            .accessibilityIdentifier("diaryCalories")
          if let caption = energyCaption {
            Text(caption)
              .heliosFont(.footnote)
              .foregroundStyle(theme.palette.text.secondary.color)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityIdentifier("diaryEnergyGoal")
          }
        }
      }
      LazyVGrid(
        columns: Array(
          repeating: GridItem(.flexible(), alignment: .top),
          count: typeSize.isAccessibilitySize ? 1 : 3), spacing: 8
      ) {
        macro(
          "Protein", value: totals.protein, goal: goal(profile?.proteinGoal),
          color: theme.palette.data.protein.color)
        macro(
          "Carbs", value: totals.carbs, goal: goal(profile?.carbGoal),
          color: theme.palette.data.carbs.color)
        macro(
          "Fat", value: totals.fat, goal: goal(profile?.fatGoal),
          color: theme.palette.data.fat.color)
      }
    }.padding(.vertical, 8)
  }

  /// "888 left of 2,350 so far" on today; a past day states the goal without judging it,
  /// because a day may be only partly logged.
  private var energyCaption: String? {
    guard let goal = goal(profile?.dailyCalorieGoal) else { return nil }
    let goalText = UnitFormatting.number(goal, locale: locale, fractionDigits: 0)
    guard isToday else { return "Goal \(goalText) kcal" }
    let left = goal - totals.calories
    let amount = UnitFormatting.number(abs(left), locale: locale, fractionDigits: 0)
    return left >= 0
      ? "\(amount) left of \(goalText) · logged so far"
      : "\(amount) over \(goalText)"
  }

  private func goal(_ value: Double?) -> Double? {
    guard let value, value.isFinite, value > 0 else { return nil }
    return value
  }

  private func share(_ calories: Double) -> Double {
    let total = totals.protein * 4 + totals.carbs * 4 + totals.fat * 9
    return total > 0 ? calories / total : 0
  }

  private func macro(
    _ title: LocalizedStringKey, value: Double, goal: Double?, color: Color
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Circle().fill(color).frame(width: 8, height: 8).accessibilityHidden(true)
        Text(title).font(.caption)
      }
      Text(
        goal.map {
          "\(NutritionInput.format(value, locale: locale)) / \(UnitFormatting.number($0, locale: locale, fractionDigits: 0)) g"
        } ?? "\(NutritionInput.format(value, locale: locale)) g"
      )
      .font(.headline).monospacedDigit()
      .fixedSize(horizontal: false, vertical: true)
      if let goal {
        // A thin bar toward the goal; it stops at full and never turns into a warning.
        GeometryReader { proxy in
          ZStack(alignment: .leading) {
            Capsule().fill(color.opacity(0.2))
            Capsule().fill(color)
              .frame(width: proxy.size.width * min(1, max(0, value / goal)))
          }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
      }
    }.frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
  }
}

#Preview {
  DiaryView()
    .modelContainer(for: [FoodItem.self, DiaryEntry.self], inMemory: true)
}
