import HeliosDesign
import SwiftData
import SwiftUI
import UIKit

struct FoodNutritionReviewView: View {
  @Environment(\.calendar) private var calendar
  @Environment(\.heliosTheme) private var theme
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var context
  @EnvironmentObject private var favorites: FoodLibraryPreferences
  let reference: FoodNutritionReference
  let onDismiss: (() -> Void)?
  @State private var amount: String
  @State private var choiceID: String
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
  @FocusState private var amountHasFocus: Bool

  /// `portion` starts the form on an amount the person typed in search ("2 slices"); it is
  /// only ever grams, ounces or one of the source's listed servings.
  init(
    reference: FoodNutritionReference,
    meal: MealType = .snack,
    date: Date = .now,
    portion: (choiceID: String, amount: Double)? = nil,
    onDismiss: (() -> Void)? = nil
  ) {
    self.reference = reference
    self.onDismiss = onDismiss
    let typed = portion.flatMap { portion -> (String, Double)? in
      guard reference.basisGrams != nil,
        ["grams", "ounces"].contains(portion.choiceID)
          || reference.servings.contains(where: { $0.id == portion.choiceID && $0.isValid })
      else { return nil }
      return (portion.choiceID, portion.amount)
    }
    _amount = State(
      initialValue: typed.map { NutritionInput.format($0.1) }
        ?? reference.basisGrams.map { NutritionInput.format($0) } ?? "1")
    _choiceID = State(
      initialValue: typed?.0 ?? (reference.basisGrams == nil ? "portions" : "grams"))
    _meal = State(initialValue: meal)
    _date = State(initialValue: date)
  }

  private var sourceServings: [FoodCatalogServing] {
    reference.basisGrams == nil ? [] : reference.servings.filter(\.isValid)
  }
  private var selectedServing: FoodCatalogServing? { sourceServings.first { $0.id == choiceID } }
  private var unit: FoodPortionUnit { FoodPortionUnit(rawValue: choiceID) ?? .portions }
  private func basis(for id: String) -> Double? {
    sourceServings.first { $0.id == id }?.gramWeight ?? reference.basisGrams
  }
  private var selection: ResolvedFoodPortion? {
    if let convertedGrams { return ResolvedFoodPortion(grams: convertedGrams, quantity: 1) }
    guard let value = NutritionInput.quantity(amount, locale: locale) else { return nil }
    return try? FoodPortionMath.resolve(value: value, unit: unit, basisGrams: basis(for: choiceID))
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
    if selectedServing != nil { return "Quantity" }
    return switch unit {
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
  private var portionSummaryText: String? {
    guard let selection else { return nil }
    if let serving = selectedServing, let value = NutritionInput.quantity(amount, locale: locale) {
      return "For \(NutritionInput.format(value, locale: locale)) × \(serving.label)"
    }
    return switch unit {
    case .grams:
      selection.grams.map { "For \(NutritionInput.format($0, locale: locale)) g" }
    case .ounces:
      NutritionInput.quantity(amount, locale: locale).map {
        "For \(NutritionInput.format($0, locale: locale)) oz"
      }
    case .portions:
      "For \(NutritionInput.format(selection.quantity, locale: locale)) × \(reference.basisDescription)"
    }
  }

  var body: some View {
    Form {
      Group {
        Section("Food") {
          Text(reference.name)
            .heliosFont(.section)
            .foregroundStyle(theme.palette.text.primary.color)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("referenceFoodName")
          Text(reference.sourceNote)
            .heliosFont(.footnote)
            .foregroundStyle(theme.palette.text.secondary.color)
            .fixedSize(horizontal: false, vertical: true)
          if FoodCatalogSourceType.contains(key: reference.id) {
            Button {
              if !favorites.setFavorite(!favorites.isFavorite(reference.id), for: reference.id) {
                saveError = FoodFavoriteEditor.EditError.limitReached.errorDescription
              }
            } label: {
              Label(
                favorites.isFavorite(reference.id) ? "Remove Favorite" : "Favorite Food",
                systemImage: favorites.isFavorite(reference.id) ? "star.fill" : "star"
              )
              .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
              .contentShape(Rectangle())
            }
            .accessibilityIdentifier("referenceFavorite")
            .accessibilityValue(
              favorites.isFavorite(reference.id) ? "Favorite" : "Not a favorite")
          }
        }

        Section {
          if reference.basisGrams != nil {
            Picker("Portion Unit", selection: $choiceID) {
              ForEach(FoodPortionUnit.allCases) { Text($0.displayName).tag($0.rawValue) }
              ForEach(sourceServings) { serving in
                Text(serving.label).tag(serving.id)
              }
            }
            .frame(minHeight: 48)
            .accessibilityIdentifier("referenceUnit")
          }
          VStack(alignment: .leading, spacing: HeliosTokens.space(1)) {
            Text(amountLabel)
              .heliosFont(.caption)
              .foregroundStyle(theme.palette.text.secondary.color)
              .fixedSize(horizontal: false, vertical: true)
            HStack {
              TextField(amountLabel, text: $amount)
                .keyboardType(.decimalPad)
                .monospacedDigit()
                .focused($amountHasFocus)
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier(inputID)
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .padding(.horizontal, HeliosTokens.space(3))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
              FoodEntryV2Surface(level: .raised, cornerRadius: HeliosTokens.radius.button)
            }
            .contentShape(Rectangle())
            .onTapGesture {
              amountHasFocus = true
            }
          }
          .padding(.vertical, 2)
          Text("Nutrition basis: \(reference.basisDescription)")
            .heliosFont(.footnote)
            .foregroundStyle(theme.palette.text.secondary.color)
            .fixedSize(horizontal: false, vertical: true)
          if let serving = selectedServing {
            Text(
              "\(serving.label) = \(NutritionInput.format(serving.gramWeight, locale: locale)) g"
            )
            .heliosFont(.footnote)
            .foregroundStyle(theme.palette.text.secondary.color)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("referenceServingWeight")
          }
        } header: {
          Text("Portion")
        } footer: {
          Text(
            reference.basisGrams == nil
              ? "Use portions of the stated serving. No weight conversion is assumed."
              : "Choose a listed serving or weight (oz means weight ounces). Changing units keeps the same amount of food."
          )
        }

        FoodEntryV2NutritionSection(
          totals: final,
          portionSummary: portionSummaryText,
          caloriesIdentifier: "referenceCalories",
          footnote: isEditing
            ? "Using your edited values for this log. Source records stay unchanged."
            : "Calories come from the source. They may differ slightly from energy calculated from macros.",
          invalidMessage: "Enter a portion above zero and valid nutrition values."
        )

        if let portion {
          MacroOverrideSection(
            itemName: reference.name, baseTotals: portion,
            basisLabel: reference.basisGrams == nil ? "per source portion" : "for this portion",
            isEditing: $isEditing,
            calories: $calories, protein: $protein, carbs: $carbs, fat: $fat)
        }

        Section {
          if FoodEntryPass2ContextFormatter.dateRelation(for: date, calendar: calendar) != .today {
            FoodEntryV2DateBadge(date: date)
          }
          Picker("Meal", selection: $meal) {
            ForEach(MealType.allCases) { Text($0.displayName).tag($0) }
          }
          .frame(minHeight: 48)
          .accessibilityIdentifier("referenceMeal")
          DatePicker("Date", selection: $date, displayedComponents: .date)
            .frame(minHeight: 48)
            .accessibilityIdentifier("referenceDate")
          Toggle("Save to My Foods", isOn: $saveToLibrary)
            .frame(minHeight: 48)
        } header: {
          Text("Meal & Date")
        }

        Section {
          Text(reference.attribution)
            .heliosFont(.footnote)
            .foregroundStyle(theme.palette.text.secondary.color)
            .fixedSize(horizontal: false, vertical: true)
          Link("View Source", destination: reference.sourceURL)
            .frame(minHeight: 48)
          Text(
            "Logging saves an independent diary snapshot so future food or menu edits never alter past days. Changing the amount resets macro edits; changing units keeps the same portion."
          )
          .heliosFont(.footnote)
          .foregroundStyle(theme.palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
        } header: {
          Text("Nutrition Source")
        }

        if didSave {
          Section {
            Label("Added to \(meal.displayName)", systemImage: "checkmark.circle.fill")
              .foregroundStyle(theme.palette.status.success.color)
              .accessibilityIdentifier("referenceSaved")
          }
        }
      }
      .listRowBackground(FoodEntryV2RowBackground())
    }
    .caliberScreen()
    .scrollDismissesKeyboard(.interactively)
    .navigationTitle("Review Food")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.visible, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .keyboard) {
        Button("Done") {
          UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .frame(minWidth: 48, minHeight: 48)
        .accessibilityIdentifier("nutritionKeyboardDone")
      }
    }
    .safeAreaInset(edge: .bottom) {
      FoodEntryV2ReviewBottomBar(
        canSave: final != nil && !didSave,
        didSave: didSave,
        addIdentifier: "referenceAdd",
        onSave: save,
        onDismiss: onDismiss
      )
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
    .onChange(of: choiceID) { previous, next in changeUnit(from: previous, to: next) }
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
    .onChange(of: amountHasFocus) { _, focused in
      guard focused else { return }
      // Portion amounts are usually replaced in full. Selecting the existing
      // number on focus makes that edit straightforward on a small screen.
      Task { @MainActor in
        await Task.yield()
        guard amountHasFocus else { return }
        UIApplication.shared.sendAction(
          #selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
      }
    }
  }

  private func changeUnit(from previous: String, to next: String) {
    let previousUnit = FoodPortionUnit(rawValue: previous) ?? .portions
    let nextUnit = FoodPortionUnit(rawValue: next) ?? .portions
    guard let previousBasis = basis(for: previous), let nextBasis = basis(for: next),
      let value = NutritionInput.quantity(amount, locale: locale),
      let old = try? FoodPortionMath.resolve(
        value: value, unit: previousUnit, basisGrams: previousBasis),
      let grams = convertedGrams ?? old.grams,
      let converted = try? FoodPortionMath.amount(
        grams: grams, unit: nextUnit, basisGrams: nextBasis)
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
        override: override, saveToLibrary: saveToLibrary,
        enteredPortionDescription: selectedServing.map {
          "\(amount) × \($0.label)"
        }, date: date, meal: meal, in: context)
      didSave = true
    } catch { saveError = "Your food could not be saved. Please try again." }
  }
}
