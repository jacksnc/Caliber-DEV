//
//  DiaryView.swift
//  Caliber (DEV)
//

import SwiftUI
import SwiftData

/// Shows the selected day's food diary: a running total at the top, and each entry
/// grouped under its meal (breakfast/lunch/dinner/snack).
struct DiaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DiaryEntry.date) private var allEntries: [DiaryEntry]

    @State private var selectedDate: Date = .now
    @State private var mealTypePresentingSheet: MealType?
    @State private var entryBeingEdited: DiaryEntry?

    private var selectedDayEntries: [DiaryEntry] {
        allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var dailyTotals: MacroTotals {
        MacroCalculator.totals(for: selectedDayEntries)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Diary date", selection: $selectedDate, displayedComponents: .date)
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
                                mealTypePresentingSheet = meal
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Diary")
            .sheet(item: $mealTypePresentingSheet) { meal in
                AddFoodView(mealType: meal, date: selectedDate)
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
    let entry: DiaryEntry

    var body: some View {
        VStack(alignment: .leading) {
            Text(entry.foodItem?.name ?? "Unknown food")
            Text("\(NutritionInput.format(entry.calories)) cal · \(NutritionInput.format(entry.protein))p \(NutritionInput.format(entry.carbs))c \(NutritionInput.format(entry.fat))f")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MacroTotalsSummaryView: View {
    let totals: MacroTotals

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(NutritionInput.format(totals.calories)) calories")
                .font(.headline)
            Text("Protein \(NutritionInput.format(totals.protein))g · Carbs \(NutritionInput.format(totals.carbs))g · Fat \(NutritionInput.format(totals.fat))g")
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
