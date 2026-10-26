//
//  MenuItemDetailView.swift
//  Caliber (DEV)
//

import SwiftData
import SwiftUI

/// Shows one menu item's official nutrition, lets the user toggle available
/// customizations (modifiers) or freely override the macros for a one-time
/// adjustment, and adds the result to the diary. Neither kind of edit ever
/// changes the saved MenuItem — every save creates a brand-new FoodItem
/// snapshot, same as every other logging flow in the app.
struct MenuItemDetailView: View {
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var modelContext
  let menuItem: MenuItem

  @State private var selectedModifierIDs: Set<UUID> = []
  @State private var quantity: String = "1"
  @State private var mealType: MealType = .snack
  @State private var date: Date = .now
  @State private var didJustSave = false
  @State private var saveError: String?
  @State private var preparedLocale = false

  @State private var isCustomizingMacros = false
  @State private var editedCalories = ""
  @State private var editedProtein = ""
  @State private var editedCarbs = ""
  @State private var editedFat = ""

  init(
    menuItem: MenuItem, initialQuantity: Double = 1, mealType: MealType = .snack, date: Date = .now
  ) {
    self.menuItem = menuItem
    _mealType = State(initialValue: mealType)
    _date = State(initialValue: date)
    _quantity = State(initialValue: NutritionInput.format(initialQuantity))
  }

  private var selectedModifiers: [MenuItemModifier] {
    menuItem.modifiers.filter { selectedModifierIDs.contains($0.id) }
  }

  /// Base nutrition plus every selected modifier's delta, for one item.
  private var customizedTotals: MacroTotals {
    selectedModifiers.reduce(
      MacroTotals(
        calories: menuItem.baseCalories,
        protein: menuItem.baseProtein,
        carbs: menuItem.baseCarbs,
        fat: menuItem.baseFat
      )
    ) { totals, modifier in
      var totals = totals
      totals.calories += modifier.calorieDelta
      totals.protein += modifier.proteinDelta
      totals.carbs += modifier.carbDelta
      totals.fat += modifier.fatDelta
      return totals
    }
  }

  /// What will actually get logged: the one-time override if the user
  /// turned that on, otherwise the modifier-adjusted base nutrition.
  private var finalTotals: MacroTotals? {
    guard isCustomizingMacros else { return customizedTotals.isValid ? customizedTotals : nil }
    return NutritionInput.totals(
      calories: editedCalories, protein: editedProtein,
      carbs: editedCarbs, fat: editedFat, locale: locale)
  }

  private var loggedTotals: MacroTotals? {
    guard let totals = finalTotals, let amount = NutritionInput.quantity(quantity, locale: locale)
    else { return nil }
    let scaled = totals.scaled(by: amount)
    return scaled.isValid ? scaled : nil
  }

  var body: some View {
    Form {
      Group {
        Section("Nutrition for this log") {
          if let totals = loggedTotals {
            Text("\(NutritionInput.format(totals.calories, locale: locale)) calories")
              .font(.headline)
            Text(
              "Protein \(NutritionInput.format(totals.protein, locale: locale))g · Carbs \(NutritionInput.format(totals.carbs, locale: locale))g · Fat \(NutritionInput.format(totals.fat, locale: locale))g"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
          } else {
            Text("Enter a quantity above zero and valid, nonnegative nutrition values.")
              .foregroundStyle(.secondary)
          }
        }

        if !menuItem.modifiers.isEmpty {
          Section("Customize") {
            ForEach(menuItem.modifiers) { modifier in
              Button {
                toggle(modifier)
              } label: {
                HStack {
                  Text(modifier.name)
                    .foregroundStyle(.primary)
                  Spacer()
                  if selectedModifierIDs.contains(modifier.id) {
                    Image(systemName: "checkmark")
                      .foregroundStyle(.tint)
                  }
                }
              }
            }
          }
        }

        MacroOverrideSection(
          itemName: menuItem.name,
          baseTotals: customizedTotals,
          isEditing: $isCustomizingMacros,
          calories: $editedCalories,
          protein: $editedProtein,
          carbs: $editedCarbs,
          fat: $editedFat
        )

        Section("Add to Diary") {
          LabeledContent("Quantity") {
            TextField("Quantity", text: $quantity).multilineTextAlignment(.trailing)
          }
          .keyboardType(.decimalPad)
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
    .onChange(of: quantity) { _, _ in didJustSave = false }
    .onChange(of: isCustomizingMacros) { _, _ in didJustSave = false }
    .onChange(of: [editedCalories, editedProtein, editedCarbs, editedFat]) { _, _ in
      didJustSave = false
    }
    .onChange(of: mealType) { _, _ in didJustSave = false }
    .onChange(of: date) { _, _ in didJustSave = false }
    .onAppear {
      guard !preparedLocale else { return }
      quantity = NutritionInput.reformatted(quantity, from: .current, to: locale)
      preparedLocale = true
    }
    .navigationTitle(menuItem.name)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Add to Diary", action: save)
          .disabled(loggedTotals == nil)
      }
    }
  }

  private func toggle(_ modifier: MenuItemModifier) {
    // A changed recipe starts with its newly calculated nutrition.
    isCustomizingMacros = false
    didJustSave = false
    if selectedModifierIDs.contains(modifier.id) {
      selectedModifierIDs.remove(modifier.id)
    } else {
      selectedModifierIDs.insert(modifier.id)
    }
  }

  private func save() {
    let modifierSuffix =
      selectedModifiers.isEmpty
      ? ""
      : " (\(selectedModifiers.map(\.name).joined(separator: ", ")))"
    let editSuffix = isCustomizingMacros ? " (edited)" : ""
    guard let totals = finalTotals, let amount = NutritionInput.quantity(quantity, locale: locale),
      loggedTotals != nil
    else { return }

    let food = FoodItem(
      name: menuItem.name + modifierSuffix + editSuffix,
      calories: totals.calories,
      proteinGrams: totals.protein,
      carbGrams: totals.carbs,
      fatGrams: totals.fat,
      servingDescription: "1 item",
      sourceType: .restaurantMenuItem,
      menuItem: menuItem
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
      didJustSave = true
    } catch {
      modelContext.delete(entry)
      modelContext.delete(food)
      saveError = error.localizedDescription
    }
  }
}

#Preview {
  NavigationStack {
    MenuItemDetailView(
      menuItem: MenuItem(
        name: "Test Item", baseCalories: 300, baseProtein: 20, baseCarbs: 30, baseFat: 10,
        category: .entree)
    )
  }
  .modelContainer(for: [FoodItem.self, DiaryEntry.self], inMemory: true)
}
