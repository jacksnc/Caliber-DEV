import SwiftData
import SwiftUI
import UIKit

/// Portion review for a recipe batch or a legacy reusable meal. Every ordinary
/// log copies independent ingredient snapshots into the diary.
struct SavedMealDetailView: View {
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var context
  let meal: SavedMeal
  @State private var mealType: MealType
  @State private var date: Date
  @State private var amount = "1"
  @State private var unit: RecipePortionUnit = .servings
  @State private var isEditing = false
  @State private var calories = ""
  @State private var protein = ""
  @State private var carbs = ""
  @State private var fat = ""
  @State private var didSave = false
  @State private var error: String?

  init(meal: SavedMeal, mealType: MealType = .lunch, date: Date = .now) {
    self.meal = meal
    _mealType = State(initialValue: mealType)
    _date = State(initialValue: date)
  }

  private var batch: RecipeBatchNutrition? { try? RecipeEditor.batch(for: meal) }
  private var amountValue: Double? { NutritionInput.quantity(amount, locale: locale) }
  private var portion: MacroTotals? {
    guard let batch, let amountValue else { return nil }
    return try? batch.portion(amount: amountValue, unit: unit)
  }
  private var override: MacroTotals? {
    guard isEditing else { return nil }
    return NutritionInput.totals(
      calories: calories, protein: protein, carbs: carbs, fat: fat, locale: locale)
  }
  private var finalTotals: MacroTotals? {
    guard let portion else { return nil }
    let values = override ?? portion
    return values.isValid ? values : nil
  }

  var body: some View {
    Form {
      Group {
        Section("Nutrition for this Portion") {
          if let finalTotals {
            Text("\(NutritionInput.format(finalTotals.calories, locale: locale)) calories")
              .font(.headline).accessibilityIdentifier("recipePortionCalories")
            Text(
              "Protein \(NutritionInput.format(finalTotals.protein, locale: locale))g · Carbs \(NutritionInput.format(finalTotals.carbs, locale: locale))g · Fat \(NutritionInput.format(finalTotals.fat, locale: locale))g"
            )
            .font(.subheadline).foregroundStyle(.secondary)
          } else {
            Text("Add valid ingredients and portions, then review again.").foregroundStyle(
              .secondary)
          }
        }
        Section("Portion") {
          Picker("Unit", selection: $unit) {
            ForEach(
              RecipePortionUnit.allCases.filter {
                $0 == .servings || meal.cookedYieldGrams != nil
              }
            ) { option in Text(option.displayName).tag(option) }
          }.accessibilityIdentifier("recipePortionUnit")
          RecipeNumberField(
            unit == .servings ? "Number of servings" : "Cooked weight (g)",
            text: $amount, identifier: "recipePortionAmount")
          Text(
            "Nutrition includes the selected ingredient amounts.\n"
              + (unit == .servings
                ? "One serving is one part of the measured batch."
                : "Cooked grams require the measured cooked batch weight.")
          )
          .font(.footnote).foregroundStyle(.secondary)
        }
        Section("Ingredients") {
          ForEach(meal.items) { item in
            VStack(alignment: .leading, spacing: 3) {
              Text(item.foodItem?.name ?? "Missing ingredient")
              Text(
                "\(NutritionInput.format(item.quantity, locale: locale)) × \(item.foodItem?.servingDescription ?? "")"
              )
              .font(.caption).foregroundStyle(.secondary)
              if item.foodItem == nil {
                Text("Edit this recipe to restore its missing ingredient.").font(.caption)
                  .foregroundStyle(.red)
              }
            }
          }
        }
        if isEditing, let portion {
          MacroOverrideSection(
            itemName: meal.name, baseTotals: portion, basisLabel: "this portion",
            isEditing: $isEditing, calories: $calories, protein: $protein,
            carbs: $carbs, fat: $fat)
        } else {
          MacroOverrideSection(
            itemName: meal.name, baseTotals: portion ?? MacroTotals(), basisLabel: "this portion",
            isEditing: $isEditing, calories: $calories, protein: $protein,
            carbs: $carbs, fat: $fat)
        }
        Section("Log This Portion") {
          Picker("Meal", selection: $mealType) {
            ForEach(MealType.allCases) { Text($0.displayName).tag($0) }
          }
          DatePicker("Date", selection: $date, displayedComponents: .date)
        }
        if didSave {
          Section {
            Label("Added to \(mealType.displayName)", systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
          }
        }
        if let error { Section { Text(error).foregroundStyle(.red) } }
      }
      .listRowBackground(CaliberRowBackground())
    }
    .caliberScreen()
    .scrollDismissesKeyboard(.interactively)
    .navigationTitle(meal.name)
    .toolbar {
      ToolbarItem(placement: .keyboard) {
        Button("Done") { dismissRecipeKeyboard() }.accessibilityIdentifier("recipeKeyboardDone")
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Add to Diary", action: logMeal)
          .disabled(finalTotals == nil || didSave).accessibilityIdentifier("recipeLog")
      }
    }
    .onChange(of: amount) { _, _ in
      isEditing = false
      didSave = false
    }
    .onChange(of: unit) { _, next in
      amount = "1"
      isEditing = false
      didSave = false
      if next == .cookedGrams {
        amount = NutritionInput.format(meal.cookedYieldGrams ?? 1, locale: locale)
      }
    }
    .onChange(of: mealType) { _, _ in didSave = false }
    .onChange(of: date) { _, _ in didSave = false }
    .onChange(of: isEditing) { _, _ in didSave = false }
    .onChange(of: [calories, protein, carbs, fat]) { _, _ in didSave = false }
  }

  private func logMeal() {
    guard !didSave, finalTotals != nil, let amountValue else { return }
    do {
      try RecipeLogger.log(
        meal: meal, amount: amountValue, unit: unit, override: override,
        date: date, mealType: mealType, in: context)
      didSave = true
    } catch {
      self.error = "Your recipe could not be logged. \(error.localizedDescription)"
    }
  }
}

private func dismissRecipeKeyboard() {
  UIApplication.shared.sendAction(
    #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
