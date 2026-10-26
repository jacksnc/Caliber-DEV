import SwiftData
import SwiftUI

/// Assemble a restaurant meal, adjust ingredient portions, then save an
/// editable nutrition snapshot without changing the restaurant's menu.
struct BuildYourOwnView: View {
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var modelContext
  let template: BuildableItemTemplate

  @State private var viewModel: BuildYourOwnViewModel
  @State private var quantity = "1"
  @State private var mealType: MealType = .lunch
  @State private var date: Date = .now
  @State private var didJustSave = false
  @State private var saveError: String?
  @State private var isCustomizingMacros = false
  @State private var editedCalories = ""
  @State private var editedProtein = ""
  @State private var editedCarbs = ""
  @State private var editedFat = ""

  init(template: BuildableItemTemplate, mealType: MealType = .lunch, date: Date = .now) {
    self.template = template
    _mealType = State(initialValue: mealType)
    _date = State(initialValue: date)
    _viewModel = State(initialValue: BuildYourOwnViewModel(template: template))
  }

  private var perItemTotals: MacroTotals? {
    if isCustomizingMacros {
      return NutritionInput.totals(
        calories: editedCalories, protein: editedProtein,
        carbs: editedCarbs, fat: editedFat, locale: locale)
    }
    return viewModel.totals.isValid ? viewModel.totals : nil
  }

  private var diaryTotals: MacroTotals? {
    guard let perItemTotals, let quantity = NutritionInput.quantity(quantity, locale: locale) else {
      return nil
    }
    let total = perItemTotals.scaled(by: quantity)
    return total.isValid ? total : nil
  }

  private var canAdd: Bool {
    viewModel.canAdd && diaryTotals != nil && !didJustSave
  }

  var body: some View {
    Form {
      Group {
        Section {
          if let totals = diaryTotals {
            Text("\(NutritionInput.format(totals.calories, locale: locale)) calories")
              .accessibilityIdentifier("builderCalories")
              .font(.headline)
            Text(
              "Protein \(NutritionInput.format(totals.protein, locale: locale))g · Carbs \(NutritionInput.format(totals.carbs, locale: locale))g · Fat \(NutritionInput.format(totals.fat, locale: locale))g"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
          } else {
            Text("Enter valid nutrition and a quantity greater than zero to see the total.")
              .foregroundStyle(.secondary)
          }
        } header: {
          Text("Diary Total")
        } footer: {
          Text(
            "Includes quantity and any macro adjustment. Swipe left on eligible proteins for Double or Regular. Tap an optional ingredient again to remove it."
          )
        }

        ForEach(viewModel.orderedCategories) { category in
          Section {
            ForEach(category.options) { option in
              optionRow(option, in: category)
            }
          } header: {
            Text(category.name + (category.isRequired ? " (required)" : " (optional)"))
          }
        }

        MacroOverrideSection(
          itemName: template.name,
          baseTotals: viewModel.totals,
          isEditing: $isCustomizingMacros,
          calories: $editedCalories,
          protein: $editedProtein,
          carbs: $editedCarbs,
          fat: $editedFat
        )

        Section {
          LabeledContent("Quantity") {
            TextField("1", text: $quantity)
              .keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing)
              .accessibilityLabel("Quantity")
          }
          Picker("Meal", selection: $mealType) {
            ForEach(MealType.allCases) { meal in
              Text(meal.displayName).tag(meal)
            }
          }
          DatePicker("Date", selection: $date, displayedComponents: .date)
        } header: {
          Text("Add to Diary")
        } footer: {
          Text(
            "Macro adjustments are for one assembled item; quantity multiplies them. Changing ingredients resets the adjustment."
          )
        }

        if !viewModel.missingRequiredCategories.isEmpty {
          Section {
            Text(
              "Choose an option for: \(viewModel.missingRequiredCategories.map(\.name).joined(separator: ", "))."
            )
            .foregroundStyle(.secondary)
          }
        }

        if diaryTotals == nil {
          Section {
            Text(
              "Use numbers of zero or greater for calories and macros, and a quantity greater than zero."
            )
            .foregroundStyle(.red)
          }
        }

        if let saveError {
          Section { Text(saveError).foregroundStyle(.red) }
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
    .navigationTitle(template.name)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Add to Diary", action: save)
          .disabled(!canAdd)
      }
    }
    .onChange(of: quantity) { _, _ in resetSaveStatus() }
    .onChange(of: mealType) { _, _ in resetSaveStatus() }
    .onChange(of: date) { _, _ in resetSaveStatus() }
    .onChange(of: isCustomizingMacros) { _, _ in resetSaveStatus() }
    .onChange(of: [editedCalories, editedProtein, editedCarbs, editedFat]) { _, _ in
      resetSaveStatus()
    }
  }

  private func optionRow(_ option: BuildComponentOption, in category: BuildComponentCategory)
    -> some View
  {
    let isDoubled = viewModel.multiplier(for: option) == 2
    let isSelected = viewModel.isSelected(option, in: category)
    return Button {
      if viewModel.toggle(option, in: category) { ingredientsChanged() }
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(option.name).foregroundStyle(.primary)
          Text(
            "\(NutritionInput.format(option.calories * viewModel.multiplier(for: option), locale: locale)) cal"
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        Spacer()
        if isDoubled {
          Text("Double").font(.caption.bold()).foregroundStyle(.orange)
        }
        if isSelected {
          Image(systemName: "checkmark").foregroundStyle(.tint)
        }
      }
    }
    .accessibilityIdentifier("ingredient-\(option.name)")
    .accessibilityValue(
      isSelected
        ? (isDoubled ? "Selected, double portion" : "Selected, regular portion") : "Not selected"
    )
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if viewModel.allowsDouble(for: option, in: category) {
        Button {
          viewModel.toggleDouble(option, in: category)
          ingredientsChanged()
        } label: {
          Label(isDoubled ? "Regular" : "Double", systemImage: isDoubled ? "1.circle" : "2.circle")
        }
        .tint(.orange)
        .accessibilityIdentifier("portion-\(option.name)")
      }
    }
  }

  private func ingredientsChanged() {
    // An override belongs to the previous recipe. Recalculate when the
    // user changes ingredients; they can adjust the new recipe afterward.
    isCustomizingMacros = false
    resetSaveStatus()
  }

  private func resetSaveStatus() {
    didJustSave = false
    saveError = nil
  }

  private func save() {
    guard canAdd, let totals = perItemTotals,
      let quantity = NutritionInput.quantity(quantity, locale: locale)
    else { return }
    let nameSuffix = viewModel.selectedOptions.map { option in
      viewModel.doubledOptionIDs.contains(option.id) ? "\(option.name) ×2" : option.name
    }.joined(separator: ", ")
    let restaurantPrefix = template.restaurant.map { "\($0.name) — " } ?? ""
    let editSuffix = isCustomizingMacros ? " (edited)" : ""

    // Each log gets its own FoodItem, so editing it never changes the menu.
    let food = FoodItem(
      name: "\(restaurantPrefix)\(template.name) (\(nameSuffix))\(editSuffix)",
      calories: totals.calories,
      proteinGrams: totals.protein,
      carbGrams: totals.carbs,
      fatGrams: totals.fat,
      servingDescription: "1 item",
      sourceType: .restaurantMenuItem
    )
    let entry = DiaryEntry(date: date, mealType: mealType, foodItem: food, quantity: quantity)
    modelContext.insert(food)
    modelContext.insert(entry)
    do {
      try modelContext.save()
      didJustSave = true
      saveError = nil
    } catch {
      // Remove just this attempted log; other unsaved app work is kept.
      modelContext.delete(entry)
      modelContext.delete(food)
      saveError = "Couldn't add this meal to your diary. Please try again."
    }
  }
}

#Preview {
  let template = BuildableItemTemplate(name: "Build Your Own Entrée")
  let base = BuildComponentCategory(
    name: "Entrée", selectionType: .single, isRequired: true, sortOrder: 0)
  base.options = [BuildComponentOption(name: "Bowl", calories: 0, protein: 0, carbs: 0, fat: 0)]
  let protein = BuildComponentCategory(
    name: "Protein", selectionType: .single, isRequired: false, sortOrder: 1)
  protein.options = [
    BuildComponentOption(
      name: "Chicken", calories: 180, protein: 32, carbs: 1, fat: 7, supportsDouble: true),
    BuildComponentOption(
      name: "Steak", calories: 150, protein: 21, carbs: 1, fat: 6, supportsDouble: true),
  ]
  template.categories = [base, protein]

  return NavigationStack { BuildYourOwnView(template: template) }
    .modelContainer(for: [FoodItem.self, DiaryEntry.self], inMemory: true)
}
