import SwiftData
import SwiftUI
import UIKit

/// Draft-first editing keeps Cancel independent of the saved meal and diary.
struct RecipeEditorView: View {
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  let meal: SavedMeal?
  @State private var name: String
  @State private var ingredients: [RecipeIngredientDraft]
  @State private var servings: String
  @State private var cooked: String
  @State private var raw: String
  @State private var error: String?
  @State private var initialError: String?
  @State private var adding = false
  @State private var editingIngredient: RecipeIngredientDraft?
  @State private var preparedLocale = false

  init(meal: SavedMeal? = nil) {
    self.meal = meal
    _name = State(initialValue: meal?.name ?? "")
    _servings = State(initialValue: NutritionInput.format(meal?.servings ?? 1))
    _cooked = State(initialValue: meal?.cookedYieldGrams.map { NutritionInput.format($0) } ?? "")
    _raw = State(initialValue: meal?.rawBatchGrams.map { NutritionInput.format($0) } ?? "")
    do {
      _ingredients = State(
        initialValue: try meal.map { try RecipeEditor.ingredients(for: $0) } ?? [])
    } catch {
      _ingredients = State(initialValue: [])
      _initialError = State(initialValue: error.localizedDescription)
    }
  }

  private func optionalWeight(_ text: String) -> Double? {
    NutritionInput.quantity(text, locale: locale)
  }
  private var weightsAreValid: Bool {
    [cooked, raw].allSatisfy {
      $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || optionalWeight($0) != nil
    }
  }
  private var batch: RecipeBatchNutrition? {
    guard initialError == nil, weightsAreValid,
      let servings = NutritionInput.quantity(servings, locale: locale)
    else { return nil }
    return try? RecipeEditor.batch(
      ingredients: ingredients, servings: servings,
      cookedYieldGrams: optionalWeight(cooked), rawBatchGrams: optionalWeight(raw))
  }

  var body: some View {
    NavigationStack {
      Form {
        Group {
          Section("Recipe or Meal") {
            TextField("Name", text: $name).accessibilityIdentifier("recipeName")
            RecipeNumberField("Batch servings", text: $servings, identifier: "recipeBatchServings")
          }
          Section("Ingredients for the Whole Batch") {
            ForEach(ingredients) { ingredient in
              Button {
                editingIngredient = ingredient
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Text(ingredient.name).foregroundStyle(.primary)
                  Text(
                    "\(NutritionInput.format(ingredient.quantity, locale: locale)) × \(ingredient.servingDescription)"
                  )
                  .font(.footnote).foregroundStyle(.secondary)
                }.frame(minHeight: 48)
              }
            }
            .onDelete { ingredients.remove(atOffsets: $0) }
            Button {
              adding = true
            } label: {
              Label("Add Ingredient", systemImage: "plus").frame(minHeight: 48)
            }.accessibilityIdentifier("recipeAddIngredient")
          }
          Section {
            RecipeNumberField(
              "Cooked batch weight (g)", text: $cooked, identifier: "recipeCookedGrams")
            RecipeNumberField("Raw batch weight (g)", text: $raw, identifier: "recipeRawGrams")
            if let factor = batch?.rawToCookedFactor {
              Text("Raw → cooked yield factor: \(NutritionInput.format(factor, locale: locale))")
                .accessibilityIdentifier("recipeYieldFactor")
            }
          } header: {
            Text("Measured Weights — Optional")
          } footer: {
            Text(
              "Cooked weight enables logging cooked grams. Enter both measured weights to see cooked ÷ raw yield. Weight changes do not change batch nutrition; adjust ingredients for additions or discarded food."
            )
          }
          if let batch {
            Section("Nutrition") {
              Text(
                "Whole batch: \(NutritionInput.format(batch.totals.calories, locale: locale)) calories"
              )
              .accessibilityIdentifier("recipeBatchCalories")
              if let serving = try? batch.portion(amount: 1, unit: .servings) {
                Text(
                  "Per serving: \(NutritionInput.format(serving.calories, locale: locale)) calories"
                )
                .accessibilityIdentifier("recipePerServingCalories")
                Text(
                  "Protein \(NutritionInput.format(serving.protein, locale: locale))g · Carbs \(NutritionInput.format(serving.carbs, locale: locale))g · Fat \(NutritionInput.format(serving.fat, locale: locale))g"
                )
                .font(.footnote)
              }
            }
          } else {
            Section {
              Text(
                initialError
                  ?? "Add ingredients and a positive serving count. Optional weights must be positive numbers when entered."
              ).font(.footnote)
            }
          }
          if let error { Section { Text(error).foregroundStyle(.red) } }
        }
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen()
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle(meal == nil ? "New Recipe or Meal" : "Edit Recipe or Meal")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", action: save)
            .disabled(
              batch == nil
                || !(1...200).contains(name.trimmingCharacters(in: .whitespacesAndNewlines).count)
            )
            .accessibilityIdentifier("recipeSave")
        }
        ToolbarItem(placement: .keyboard) {
          Button("Done") { resignKeyboard() }.accessibilityIdentifier("recipeKeyboardDone")
        }
      }
      .sheet(isPresented: $adding) {
        RecipeIngredientPicker { ingredients.append($0) }
      }
      .sheet(item: $editingIngredient) { ingredient in
        RecipeIngredientPicker(initialIngredient: ingredient) { updated in
          if let index = ingredients.firstIndex(where: { $0.id == updated.id }) {
            ingredients[index] = updated
          }
        }
      }
      .onAppear {
        guard !preparedLocale else { return }
        servings = NutritionInput.reformatted(servings, from: .current, to: locale)
        cooked = NutritionInput.reformatted(cooked, from: .current, to: locale)
        raw = NutritionInput.reformatted(raw, from: .current, to: locale)
        preparedLocale = true
      }
    }
  }

  private func save() {
    guard let batch else { return }
    do {
      try RecipeEditor.save(
        meal: meal, name: name, ingredients: ingredients, servings: batch.servings,
        cookedYieldGrams: batch.cookedYieldGrams, rawBatchGrams: batch.rawBatchGrams, in: context)
      dismiss()
    } catch { self.error = error.localizedDescription }
  }
}

/// Full-width numeric fields stay editable with large values and large text.
struct RecipeNumberField: View {
  let title: String
  @Binding var text: String
  let identifier: String
  @FocusState private var focused: Bool
  init(_ title: String, text: Binding<String>, identifier: String) {
    self.title = title
    _text = text
    self.identifier = identifier
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
      TextField(title, text: $text).keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing).frame(minHeight: 48)
        .focused($focused).accessibilityIdentifier(identifier)
    }
    .onChange(of: focused) { _, focused in
      guard focused else { return }
      Task { @MainActor in
        await Task.yield()
        guard self.focused else { return }
        UIApplication.shared.sendAction(
          #selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
      }
    }
  }
}

@MainActor
private func resignKeyboard() {
  UIApplication.shared.sendAction(
    #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
