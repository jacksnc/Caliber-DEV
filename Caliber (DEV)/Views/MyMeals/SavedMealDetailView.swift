//
//  SavedMealDetailView.swift
//  Caliber (DEV)
//

import SwiftUI
import SwiftData

/// Shows a saved meal's contents and combined nutrition, and logs every
/// contained food to the diary at once under a chosen meal slot and date.
struct SavedMealDetailView: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    let meal: SavedMeal

    @State private var mealType: MealType = .lunch
    @State private var date: Date = .now
    @State private var didJustSave = false
    @State private var saveError: String?
    @State private var isCustomizingMacros = false
    @State private var editedCalories = ""
    @State private var editedProtein = ""
    @State private var editedCarbs = ""
    @State private var editedFat = ""

    private var totals: MacroTotals {
        MacroCalculator.totals(for: meal.items)
    }

    private var finalTotals: MacroTotals? {
        guard isCustomizingMacros else { return totals.isValid ? totals : nil }
        return NutritionInput.totals(calories: editedCalories, protein: editedProtein,
                                     carbs: editedCarbs, fat: editedFat, locale: locale)
    }

    var body: some View {
        Form {
            Section("Nutrition for this meal") {
                let totals = finalTotals ?? self.totals
                Text("\(NutritionInput.format(totals.calories, locale: locale)) calories")
                    .font(.headline)
                Text("Protein \(NutritionInput.format(totals.protein, locale: locale))g · Carbs \(NutritionInput.format(totals.carbs, locale: locale))g · Fat \(NutritionInput.format(totals.fat, locale: locale))g")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Includes") {
                ForEach(meal.items) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.foodItem?.name ?? "Unknown food")
                        Text("\(NutritionInput.format(item.calories, locale: locale)) cal · \(NutritionInput.format(item.protein, locale: locale))p \(NutritionInput.format(item.carbs, locale: locale))c \(NutritionInput.format(item.fat, locale: locale))f")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            MacroOverrideSection(
                itemName: meal.name, baseTotals: totals,
                isEditing: $isCustomizingMacros,
                calories: $editedCalories, protein: $editedProtein,
                carbs: $editedCarbs, fat: $editedFat
            )

            if isCustomizingMacros {
                Section {
                    Text("One serving is this entire meal. Your adjusted meal will appear as one diary entry.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("Log This Meal") {
                Picker("Meal", selection: $mealType) {
                    ForEach(MealType.allCases) { meal in
                        Text(meal.displayName).tag(meal)
                    }
                }
                DatePicker("Date", selection: $date, displayedComponents: .date)
            }

            if didJustSave {
                Section {
                    Label("Added to \(mealType.displayName)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .alert("Couldn't Save Meal", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "Please try again.") }
        .onChange(of: [editedCalories, editedProtein, editedCarbs, editedFat]) { _, _ in didJustSave = false }
        .onChange(of: isCustomizingMacros) { _, _ in didJustSave = false }
        .onChange(of: mealType) { _, _ in didJustSave = false }
        .onChange(of: date) { _, _ in didJustSave = false }
        .navigationTitle(meal.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add to Diary", action: logMeal)
                    .disabled(meal.items.isEmpty || finalTotals == nil)
            }
        }
    }

    private func logMeal() {
        guard let totals = finalTotals else { return }
        var newFoods: [FoodItem] = []
        var newEntries: [DiaryEntry] = []

        if isCustomizingMacros {
            let food = FoodItem(name: meal.name, calories: totals.calories,
                                proteinGrams: totals.protein, carbGrams: totals.carbs,
                                fatGrams: totals.fat, servingDescription: "1 meal")
            newFoods.append(food)
            newEntries.append(DiaryEntry(date: date, mealType: mealType, foodItem: food))
        } else {
            // Copy each saved food so a later diary edit cannot alter this meal.
            for item in meal.items {
                guard let source = item.foodItem else { continue }
                let food = FoodItem(name: source.name, calories: source.calories,
                                    proteinGrams: source.proteinGrams, carbGrams: source.carbGrams,
                                    fatGrams: source.fatGrams, servingDescription: source.servingDescription,
                                    sourceType: source.sourceType, menuItem: source.menuItem)
                newFoods.append(food)
                newEntries.append(DiaryEntry(date: date, mealType: mealType, foodItem: food, quantity: item.quantity))
            }
        }
        guard !newEntries.isEmpty else { return }
        newFoods.forEach { modelContext.insert($0) }
        newEntries.forEach { modelContext.insert($0) }
        do {
            try modelContext.save()
            didJustSave = true
        } catch {
            newEntries.forEach { modelContext.delete($0) }
            newFoods.forEach { modelContext.delete($0) }
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    let food = FoodItem(name: "Oatmeal", calories: 150, proteinGrams: 5, carbGrams: 27, fatGrams: 3, servingDescription: "1 cup")
    let meal = SavedMeal(name: "My Usual Breakfast")
    meal.items = [SavedMealItem(foodItem: food, quantity: 1)]

    return NavigationStack {
        SavedMealDetailView(meal: meal)
    }
    .modelContainer(for: [SavedMeal.self, SavedMealItem.self, FoodItem.self, DiaryEntry.self], inMemory: true)
}
