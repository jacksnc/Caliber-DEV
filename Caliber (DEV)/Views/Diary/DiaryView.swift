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

  var body: some View {
    NavigationStack {
      List {
        Group {
          Section {
            DatePicker("Diary date", selection: $selectedDate, displayedComponents: .date)
              .accessibilityIdentifier("diaryDate")
            Button {
              copyRequest = DiaryCopyRequest(date: selectedDate, meal: nil)
            } label: {
              Label {
                Text("Copy a Day").fixedSize(horizontal: false, vertical: true)
              } icon: {
                Image(systemName: "doc.on.doc")
              }
              .frame(minHeight: 48)
            }
            .accessibilityIdentifier("diaryCopyDay")
          } header: {
            CaliberHeader("Fuel", identifier: "Fuel", overline: Text("Diary"))
              .caliberSectionHeader()
          }
          Section {
            MacroTotalsSummaryView(totals: dailyTotals)
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
              "\(NutritionInput.format(MacroCalculator.totals(for: entries).calories, locale: locale)) cal"
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
        "\(NutritionInput.format(entry.calories, locale: locale)) cal · \(NutritionInput.format(entry.protein, locale: locale))p \(NutritionInput.format(entry.carbs, locale: locale))c \(NutritionInput.format(entry.fat, locale: locale))f"
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }
}

private struct MacroTotalsSummaryView: View {
  @Environment(\.locale) private var locale
  @Environment(\.heliosTheme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  let totals: MacroTotals

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
        Text("\(NutritionInput.format(totals.calories, locale: locale)) calories")
          .heliosFont(.metricValue).accessibilityIdentifier("diaryCalories")
      }
      LazyVGrid(
        columns: Array(
          repeating: GridItem(.flexible(), alignment: .top),
          count: typeSize.isAccessibilitySize ? 1 : 3), spacing: 8
      ) {
        macro("Protein", value: totals.protein, color: theme.palette.data.protein.color)
        macro("Carbs", value: totals.carbs, color: theme.palette.data.carbs.color)
        macro("Fat", value: totals.fat, color: theme.palette.data.fat.color)
      }
    }.padding(.vertical, 8)
  }

  private func share(_ calories: Double) -> Double {
    let total = totals.protein * 4 + totals.carbs * 4 + totals.fat * 9
    return total > 0 ? calories / total : 0
  }

  private func macro(_ title: LocalizedStringKey, value: Double, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Circle().fill(color).frame(width: 8, height: 8).accessibilityHidden(true)
        Text(title).font(.caption)
      }
      Text("\(NutritionInput.format(value, locale: locale)) g").font(.headline).monospacedDigit()
    }.frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
  }
}

#Preview {
  DiaryView()
    .modelContainer(for: [FoodItem.self, DiaryEntry.self], inMemory: true)
}
