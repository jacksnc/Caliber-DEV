import SwiftData
import SwiftUI
import UIKit

struct FoodNutritionReviewView: View {
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var context
  @EnvironmentObject private var favorites: FoodLibraryPreferences
  let reference: FoodNutritionReference
  @State private var amount: String
  @State private var unit: FoodPortionUnit
  @State private var meal: MealType
  @State private var date: Date
  @State private var saveToLibrary = false
  @State private var isEditing = false
  @State private var calories = ""
  @State private var protein = ""
  @State private var carbs = ""
  @State private var fat = ""
  @State private var didSave = false
  @State private var saveError: String?
  @State private var preparedLocale = false
  // A display-unit change preserves the exact selected mass and personal edits.
  @State private var convertedGrams: Double?
  @State private var convertedText: String?

  init(reference: FoodNutritionReference, meal: MealType = .snack, date: Date = .now) {
    self.reference = reference
    _amount = State(initialValue: reference.basisGrams.map { NutritionInput.format($0) } ?? "1")
    _unit = State(initialValue: reference.basisGrams == nil ? .portions : .grams)
    _meal = State(initialValue: meal)
    _date = State(initialValue: date)
  }

  private var selection: ResolvedFoodPortion? {
    if let convertedGrams { return ResolvedFoodPortion(grams: convertedGrams, quantity: 1) }
    guard let value = NutritionInput.quantity(amount, locale: locale) else { return nil }
    return try? FoodPortionMath.resolve(value: value, unit: unit, basisGrams: reference.basisGrams)
  }
  private var portion: MacroTotals? {
    guard let selection else { return nil }
    return try? reference.portionTotals(grams: selection.grams)
  }
  private var override: MacroTotals? {
    isEditing
      ? NutritionInput.totals(
        calories: calories, protein: protein, carbs: carbs, fat: fat, locale: locale) : nil
  }
  private var final: MacroTotals? {
    guard let portion, let selection, !isEditing || override != nil else { return nil }
    let result = (override ?? portion).scaled(by: selection.quantity)
    return result.isValid ? result : nil
  }
  private var amountLabel: String {
    switch unit {
    case .grams: "Weight (g)"
    case .ounces: "Weight (oz)"
    case .portions: "Number of Portions"
    }
  }
  private var inputID: String {
    switch unit {
    case .grams: "referenceGrams"
    case .ounces: "referenceOunces"
    case .portions: "referenceQuantity"
    }
  }

  var body: some View {
    Form {
      Section("Food") {
        Text(reference.name).font(.headline).accessibilityIdentifier("referenceFoodName")
        Text(reference.sourceNote).font(.footnote)
        if reference.id.hasPrefix("usda-foundation:") {
          Button {
            if !favorites.setFavorite(!favorites.isFavorite(reference.id), for: reference.id) {
              saveError = FoodFavoriteEditor.EditError.limitReached.errorDescription
            }
          } label: {
            Label(
              favorites.isFavorite(reference.id) ? "Remove Favorite" : "Favorite Food",
              systemImage: favorites.isFavorite(reference.id) ? "star.fill" : "star"
            )
            .frame(minHeight: 48)
          }.accessibilityIdentifier("referenceFavorite")
            .accessibilityValue(favorites.isFavorite(reference.id) ? "Favorite" : "Not a favorite")
        }
      }
      Section {
        if reference.basisGrams != nil {
          Picker("Portion Unit", selection: $unit) {
            ForEach(FoodPortionUnit.allCases) { Text($0.displayName).tag($0) }
          }.accessibilityIdentifier("referenceUnit")
        }
        LabeledContent(amountLabel) {
          TextField(amountLabel, text: $amount).keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing).accessibilityIdentifier(inputID)
        }.frame(minHeight: 48)
        Text("One source portion: \(reference.basisDescription)").font(.footnote)
      } header: {
        Text("Portion")
      } footer: {
        Text(
          reference.basisGrams == nil
            ? "Use portions of the stated serving. No weight conversion is assumed."
            : "oz means weight ounces. Cups and tablespoons need a known weight for this food.")
      }
      Section("Nutrition for this log") {
        if let final {
          Text("\(NutritionInput.format(final.calories, locale: locale)) calories").font(.headline)
            .accessibilityIdentifier("referenceCalories")
          Text(
            "Protein \(NutritionInput.format(final.protein, locale: locale))g · Carbs \(NutritionInput.format(final.carbs, locale: locale))g · Fat \(NutritionInput.format(final.fat, locale: locale))g"
          )
        } else {
          Text("Enter a portion above zero and valid nutrition values.")
        }
      }
      if let portion {
        MacroOverrideSection(
          itemName: reference.name, baseTotals: portion,
          basisLabel: reference.basisGrams == nil ? "per source portion" : "for this portion",
          isEditing: $isEditing,
          calories: $calories, protein: $protein, carbs: $carbs, fat: $fat)
      }
      Section("Add to Diary") {
        Picker("Meal", selection: $meal) {
          ForEach(MealType.allCases) { Text($0.displayName).tag($0) }
        }.accessibilityIdentifier("referenceMeal")
        DatePicker("Date", selection: $date, displayedComponents: .date)
        Toggle("Save to My Foods", isOn: $saveToLibrary)
      }
      Section("Nutrition Source") {
        Text(reference.attribution).font(.footnote)
        Link("View Source", destination: reference.sourceURL).frame(minHeight: 48)
        Text(
          "You can adjust nutrition for this portion before logging. Edits apply to your copy. Changing the amount resets edits; changing units keeps the same portion."
        ).font(.footnote)
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
        .frame(minWidth: 48, minHeight: 48).accessibilityIdentifier("nutritionKeyboardDone")
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Add to Diary", action: save).disabled(final == nil || didSave)
          .frame(minWidth: 48, minHeight: 48).accessibilityIdentifier("referenceAdd")
      }
    }
    .alert(
      "Couldn't Complete Action",
      isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
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
    .onChange(of: unit) { previous, next in changeUnit(from: previous, to: next) }
    .onChange(of: amount) { _, value in
      if value == convertedText {
        convertedText = nil
        return
      }
      convertedText = nil
      convertedGrams = nil
      isEditing = false
      didSave = false
    }
    .onChange(of: [calories, protein, carbs, fat]) { _, _ in didSave = false }
    .onChange(of: meal) { _, _ in didSave = false }
    .onChange(of: date) { _, _ in didSave = false }
    .onChange(of: isEditing) { _, _ in didSave = false }
  }

  private func changeUnit(from previous: FoodPortionUnit, to next: FoodPortionUnit) {
    guard let basis = reference.basisGrams,
      let value = NutritionInput.quantity(amount, locale: locale),
      let old = try? FoodPortionMath.resolve(value: value, unit: previous, basisGrams: basis),
      let grams = convertedGrams ?? old.grams,
      let converted = try? FoodPortionMath.amount(grams: grams, unit: next, basisGrams: basis)
    else {
      convertedGrams = nil
      isEditing = false
      didSave = false
      return
    }
    let text = NutritionInput.format(converted, locale: locale)
    convertedGrams = grams
    convertedText = text == amount ? nil : text
    amount = text
  }
  private func save() {
    guard !didSave, final != nil, let selection else { return }
    do {
      try ReferenceFoodLogger.log(
        reference: reference, grams: selection.grams, quantity: selection.quantity,
        override: override, saveToLibrary: saveToLibrary, date: date, meal: meal, in: context)
      didSave = true
    } catch { saveError = "Your food could not be saved. Please try again." }
  }
}
