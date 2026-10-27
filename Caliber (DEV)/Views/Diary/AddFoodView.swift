//
//  AddFoodView.swift
//  Caliber (DEV)
//

import SwiftData
import SwiftUI

/// A simple manual-entry form for adding a food to a specific meal on a
/// specific day. Used both as its own "Add" tab and as a sheet from Diary.
struct AddFoodView: View {
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var modelContext

  @State private var mealType: MealType
  @State private var date: Date
  @State private var name: String = ""
  @State private var calories: String = ""
  @State private var protein: String = ""
  @State private var carbs: String = ""
  @State private var fat: String = ""
  @State private var servingDescription: String = ""
  @State private var quantity: String = "1"
  @State private var saveToLibrary: Bool = true
  @State private var didJustSave = false
  @State private var saveError: String?

  /// `prefill` comes from a scanned label or a confirmed estimate; every field stays editable.
  init(mealType: MealType, date: Date, prefill: FoodEntryPrefill? = nil) {
    _mealType = State(initialValue: mealType)
    _date = State(initialValue: date)
    if let prefill {
      _name = State(initialValue: prefill.name)
      _servingDescription = State(initialValue: prefill.servingDescription)
      _calories = State(initialValue: prefill.calories)
      _protein = State(initialValue: prefill.protein)
      _carbs = State(initialValue: prefill.carbs)
      _fat = State(initialValue: prefill.fat)
    }
  }

  private var totals: MacroTotals? {
    NutritionInput.totals(
      calories: calories,
      protein: protein.isEmpty ? "0" : protein,
      carbs: carbs.isEmpty ? "0" : carbs,
      fat: fat.isEmpty ? "0" : fat, locale: locale)
  }

  private var canSave: Bool {
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let totals, let amount = NutritionInput.quantity(quantity, locale: locale)
    else { return false }
    return totals.scaled(by: amount).isValid
  }

  var body: some View {
    NavigationStack {
      Form {
        Group {
          Section("Food") {
            TextField("Name", text: $name)
            TextField("Serving (e.g. 1 cup)", text: $servingDescription)
            TextField("Quantity", text: $quantity)
              .keyboardType(.decimalPad)
            Toggle("Save to My Foods", isOn: $saveToLibrary)
          }

          Section("Macros (per serving)") {
            TextField("Calories", text: $calories)
              .keyboardType(.decimalPad)
            TextField("Protein (g)", text: $protein)
              .keyboardType(.decimalPad)
            TextField("Carbs (g)", text: $carbs)
              .keyboardType(.decimalPad)
            TextField("Fat (g)", text: $fat)
              .keyboardType(.decimalPad)
          }

          Section("Meal") {
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
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen()
      .alert(
        "Couldn't Save Food",
        isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
      ) {
        Button("OK", role: .cancel) { saveError = nil }
      } message: {
        Text(saveError ?? "Please try again.")
      }
      .navigationTitle("Add Food")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", action: save)
            .disabled(!canSave)
        }
      }
    }
  }

  private func save() {
    guard canSave, let totals, let amount = NutritionInput.quantity(quantity, locale: locale) else {
      return
    }
    let food = FoodItem(
      name: name,
      calories: totals.calories,
      proteinGrams: totals.protein,
      carbGrams: totals.carbs,
      fatGrams: totals.fat,
      servingDescription: servingDescription.isEmpty ? "1 serving" : servingDescription,
      isSavedToLibrary: saveToLibrary
    )
    let entry = DiaryEntry(
      date: date,
      mealType: mealType,
      foodItem: food,
      quantity: amount
    )
    modelContext.insert(food)
    modelContext.insert(entry)
    do {
      try modelContext.save()
    } catch {
      modelContext.delete(entry)
      modelContext.delete(food)
      saveError = error.localizedDescription
      return
    }

    name = ""
    calories = ""
    protein = ""
    carbs = ""
    fat = ""
    servingDescription = ""
    quantity = "1"

    didJustSave = true
  }
}

#Preview {
  AddFoodView(mealType: .breakfast, date: .now)
    .modelContainer(for: [FoodItem.self, DiaryEntry.self], inMemory: true)
}
