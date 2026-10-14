import SwiftData
import SwiftUI
import UIKit

struct FoodNutritionReviewView: View {
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var context
  let reference: FoodNutritionReference
  @State private var amount = "100"
  @State private var quantity = "1"
  @State private var meal: MealType = .snack
  @State private var date = Date.now
  @State private var saveToLibrary = false
  @State private var isEditing = false
  @State private var calories = ""
  @State private var protein = ""
  @State private var carbs = ""
  @State private var fat = ""
  @State private var didSave = false
  @State private var saveError: String?
  @State private var preparedLocale = false

  init(reference: FoodNutritionReference) {
    self.reference = reference
    _amount = State(initialValue: reference.basisGrams.map { NutritionInput.format($0) } ?? "100")
  }

  private var grams: Double? {
    reference.basisGrams == nil ? nil : NutritionInput.quantity(amount, locale: locale)
  }
  private var portion: MacroTotals? { try? reference.portionTotals(grams: grams) }
  private var override: MacroTotals? {
    isEditing
      ? NutritionInput.totals(
        calories: calories, protein: protein, carbs: carbs, fat: fat, locale: locale)
      : nil
  }
  private var final: MacroTotals? {
    guard let portion, !isEditing || override != nil,
      let quantity = NutritionInput.quantity(quantity, locale: locale)
    else { return nil }
    let result = (override ?? portion).scaled(by: quantity)
    return result.isValid ? result : nil
  }

  var body: some View {
    Form {
      Section("Food") {
        Text(reference.name).font(.headline).accessibilityIdentifier("referenceFoodName")
        Text(reference.sourceNote).font(.footnote)
      }
      Section("Portion") {
        if reference.basisGrams != nil {
          LabeledContent("Weight (g)") {
            TextField("Grams", text: $amount).keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing).accessibilityIdentifier("referenceGrams")
          }
        } else {
          Text("One portion: \(reference.basisDescription)")
          LabeledContent("Number of Portions") {
            TextField("Portions", text: $quantity).keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing).accessibilityIdentifier("referenceQuantity")
          }
        }
      }
      Section("Nutrition for this log") {
        if let final {
          Text("\(NutritionInput.format(final.calories, locale: locale)) calories")
            .font(.headline).accessibilityIdentifier("referenceCalories")
          Text(
            "Protein \(NutritionInput.format(final.protein, locale: locale))g · Carbs \(NutritionInput.format(final.carbs, locale: locale))g · Fat \(NutritionInput.format(final.fat, locale: locale))g"
          )
        } else {
          Text("Enter a portion above zero and valid nutrition values.")
        }
      }
      if let portion {
        MacroOverrideSection(
          itemName: reference.name, baseTotals: portion, isEditing: $isEditing,
          calories: $calories, protein: $protein, carbs: $carbs, fat: $fat)
      }
      Section("Add to Diary") {
        Picker("Meal", selection: $meal) {
          ForEach(MealType.allCases) { Text($0.displayName).tag($0) }
        }
        DatePicker("Date", selection: $date, displayedComponents: .date)
        Toggle("Save to My Foods", isOn: $saveToLibrary)
      }
      Section("Nutrition Source") {
        Text(reference.attribution).font(.footnote)
        Link("View Source", destination: reference.sourceURL).frame(minHeight: 48)
        Text("You can adjust the nutrition before logging. Edits apply to your copy.").font(
          .footnote)
      }
      if didSave {
        Section {
          Label("Added to \(meal.displayName)", systemImage: "checkmark.circle")
            .accessibilityIdentifier("referenceSaved")
        }
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .navigationTitle("Review Food")
    .toolbar {
      ToolbarItem(placement: .keyboard) {
        Button("Done") {
          UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .frame(minWidth: 48, minHeight: 48)
        .accessibilityIdentifier("nutritionKeyboardDone")
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Add to Diary", action: save).disabled(final == nil || didSave)
          .frame(minWidth: 48, minHeight: 48).accessibilityIdentifier("referenceAdd")
      }
    }
    .alert(
      "Couldn't Save Food",
      isPresented: Binding(
        get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    ) {
      Button("OK", role: .cancel) { saveError = nil }
    } message: {
      Text(saveError ?? "Please try again.")
    }
    .onAppear {
      guard !preparedLocale else { return }
      amount = NutritionInput.reformatted(amount, from: .current, to: locale)
      preparedLocale = true
    }
    .onChange(of: amount) { _, _ in
      isEditing = false
      didSave = false
    }
    .onChange(of: quantity) { _, _ in didSave = false }
    .onChange(of: [calories, protein, carbs, fat]) { _, _ in didSave = false }
    .onChange(of: meal) { _, _ in didSave = false }
    .onChange(of: date) { _, _ in didSave = false }
    .onChange(of: isEditing) { _, _ in didSave = false }
  }

  private func save() {
    guard final != nil, let quantity = NutritionInput.quantity(quantity, locale: locale) else {
      return
    }
    do {
      try ReferenceFoodLogger.log(
        reference: reference, grams: grams, quantity: quantity, override: override,
        saveToLibrary: saveToLibrary, date: date, meal: meal, in: context)
      didSave = true
    } catch {
      saveError = "Your food could not be saved. Please try again."
    }
  }
}
