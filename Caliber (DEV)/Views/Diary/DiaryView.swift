//
//  DiaryView.swift
//  Caliber (DEV)
//

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
        Section {
          DatePicker("Diary date", selection: $selectedDate, displayedComponents: .date)
            .accessibilityIdentifier("diaryDate")
          Button {
            copyRequest = DiaryCopyRequest(date: selectedDate, meal: nil)
          } label: {
            Label("Copy a Day", systemImage: "doc.on.doc").frame(minHeight: 48)
          }
          .accessibilityIdentifier("diaryCopyDay")
        }
        Section {
          MacroTotalsSummaryView(totals: dailyTotals)
        }

        ForEach(MealType.allCases) { meal in
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
            HStack {
              Text(meal.displayName)
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
      .navigationTitle("Diary")
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
  let totals: MacroTotals

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("\(NutritionInput.format(totals.calories, locale: locale)) calories")
        .font(.headline).accessibilityIdentifier("diaryCalories")
      Text(
        "Protein \(NutritionInput.format(totals.protein, locale: locale))g · Carbs \(NutritionInput.format(totals.carbs, locale: locale))g · Fat \(NutritionInput.format(totals.fat, locale: locale))g"
      )
      .font(.subheadline)
      .foregroundStyle(.secondary)
    }
    .padding(.vertical, 4)
  }
}

#Preview {
  DiaryView()
    .modelContainer(for: [FoodItem.self, DiaryEntry.self], inMemory: true)
}
