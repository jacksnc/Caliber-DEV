//
//  SavedFoodDetailView.swift
//  Caliber (DEV)
//

import HeliosDesign
import SwiftData
import SwiftUI
import UIKit

/// Logs a saved "My Foods" item to the diary. Like restaurant items, logging
/// always creates a brand-new FoodItem snapshot — so a one-time macro
/// override here never changes the saved library entry.
struct SavedFoodDetailView: View {
  @Environment(\.calendar) private var calendar
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.heliosTheme) private var theme
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var favorites: FoodLibraryPreferences
  let food: FoodItem
  let onDismiss: (() -> Void)?

  @State private var quantity: String = "1"
  @State private var mealType: MealType = .snack
  @State private var date: Date = .now
  @State private var didJustSave = false
  @State private var saveError: String?

  @State private var isCustomizingMacros = false
  @State private var editedCalories = ""
  @State private var editedProtein = ""
  @State private var editedCarbs = ""
  @State private var editedFat = ""
  @FocusState private var quantityHasFocus: Bool

  init(
    food: FoodItem,
    initialQuantity: Double = 1,
    mealType: MealType = .snack,
    date: Date = .now,
    onDismiss: (() -> Void)? = nil
  ) {
    self.food = food
    self.onDismiss = onDismiss
    _quantity = State(initialValue: NutritionInput.format(initialQuantity))
    _mealType = State(initialValue: mealType)
    _date = State(initialValue: date)
  }
  @State private var preparedLocale = false
  private var favoriteKey: String { FoodReuseIndex.key(for: food) }

  private var baseTotals: MacroTotals {
    MacroTotals(
      calories: food.calories, protein: food.proteinGrams, carbs: food.carbGrams, fat: food.fatGrams
    )
  }

  private var finalTotals: MacroTotals? {
    guard isCustomizingMacros else { return baseTotals.isValid ? baseTotals : nil }
    return NutritionInput.totals(
      calories: editedCalories, protein: editedProtein,
      carbs: editedCarbs, fat: editedFat, locale: locale)
  }

  private var loggedTotals: MacroTotals? {
    guard let totals = finalTotals,
      let amount = NutritionInput.quantity(quantity, locale: locale)
    else { return nil }
    let scaled = totals.scaled(by: amount)
    return scaled.isValid ? scaled : nil
  }

  private var portionSummaryText: String? {
    guard let amount = NutritionInput.quantity(quantity, locale: locale) else { return nil }
    return "For \(NutritionInput.format(amount, locale: locale)) × \(food.servingDescription)"
  }

  var body: some View {
    Form {
      Group {
        Section {
          VStack(alignment: .leading, spacing: HeliosTokens.space(1)) {
            Text(food.name)
              .heliosFont(.section)
              .foregroundStyle(theme.palette.text.primary.color)
              .fixedSize(horizontal: false, vertical: true)
            Text("Serving basis: \(food.servingDescription)")
              .heliosFont(.footnote)
              .foregroundStyle(theme.palette.text.secondary.color)
              .fixedSize(horizontal: false, vertical: true)
          }

          VStack(alignment: .leading, spacing: HeliosTokens.space(1)) {
            Text("Quantity")
              .heliosFont(.caption)
              .foregroundStyle(theme.palette.text.secondary.color)
              .fixedSize(horizontal: false, vertical: true)
            HStack {
              TextField("Quantity", text: $quantity)
                .keyboardType(.decimalPad)
                .monospacedDigit()
                .focused($quantityHasFocus)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, minHeight: 48)
                .accessibilityIdentifier("savedFoodQuantity")
            }
            .padding(.horizontal, HeliosTokens.space(3))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
              FoodEntryV2Surface(level: .raised, cornerRadius: HeliosTokens.radius.button)
            }
            .contentShape(Rectangle())
            .onTapGesture {
              quantityHasFocus = true
            }
          }
          .padding(.vertical, 2)

          Button {
            do {
              try FoodFavoriteEditor.setFavorite(
                !favorites.isFavorite(favoriteKey), food: food, preferences: favorites,
                in: modelContext)
            } catch { saveError = error.localizedDescription }
          } label: {
            Label(
              favorites.isFavorite(favoriteKey) ? "Remove Favorite" : "Favorite Food",
              systemImage: favorites.isFavorite(favoriteKey) ? "star.fill" : "star"
            )
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
          }
          .accessibilityIdentifier("savedFoodFavorite")
        } header: {
          Text("Selected Food & Portion")
        } footer: {
          Text(
            "Favorites stay in My Foods for quick reuse. Logging saves an independent diary snapshot."
          )
        }

        Section {
          FoodEntryV2NutritionOverviewCard(
            totals: loggedTotals,
            portionSummary: portionSummaryText,
            caloriesIdentifier: "savedFoodCalories",
            footnote: isCustomizingMacros
              ? "Using your edited values for this log. Your saved food stays unchanged."
              : "Calories come from your saved food. They may differ slightly from energy calculated from macros.",
            invalidMessage:
              "Enter a quantity above zero and valid, nonnegative nutrition values."
          )
          .foodEntryV2CardRow()
        }

        MacroOverrideSection(
          itemName: food.name,
          baseTotals: baseTotals,
          isEditing: $isCustomizingMacros,
          calories: $editedCalories,
          protein: $editedProtein,
          carbs: $editedCarbs,
          fat: $editedFat
        )

        Section {
          if FoodEntryPass2ContextFormatter.dateRelation(for: date, calendar: calendar) != .today {
            FoodEntryV2DateBadge(date: date)
          }
          Picker("Meal", selection: $mealType) {
            ForEach(MealType.allCases) { meal in
              Text(meal.displayName).tag(meal)
            }
          }
          .frame(minHeight: 48)
          .accessibilityIdentifier("savedFoodMeal")
          DatePicker("Date", selection: $date, displayedComponents: .date)
            .frame(minHeight: 48)
            .accessibilityIdentifier("savedFoodDate")
        } header: {
          Text("Meal & Date")
        }

        if didJustSave {
          Section {
            Label("Added to \(mealType.displayName)", systemImage: "checkmark.circle.fill")
              .accessibilityIdentifier("savedFoodSaved")
              .foregroundStyle(theme.palette.status.success.color)
          }
        }
      }
      .listRowBackground(FoodEntryV2RowBackground())
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
    .navigationTitle(food.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.visible, for: .navigationBar)
    .onAppear {
      guard !preparedLocale else { return }
      quantity = NutritionInput.reformatted(quantity, from: .current, to: locale)
      preparedLocale = true
    }
    .scrollDismissesKeyboard(.interactively)
    .toolbar {
      if !typeSize.isAccessibilitySize {
        if let onDismiss {
          ToolbarItem(placement: .cancellationAction) {
            Button(didJustSave ? "Done" : "Cancel", action: onDismiss)
              .frame(minWidth: 48, minHeight: 48)
              .accessibilityIdentifier("foodEntryQuickReviewClose")
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Add to Diary", action: save)
            .disabled(loggedTotals == nil || didJustSave)
            .frame(minWidth: 48, minHeight: 48)
            .accessibilityIdentifier("savedFoodAdd")
        }
      }

      ToolbarItem(placement: .keyboard) {
        Button("Done") {
          UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .frame(minWidth: 48, minHeight: 48)
        .accessibilityIdentifier("savedFoodKeyboardDone")
      }
    }
    .safeAreaInset(edge: .bottom) {
      if typeSize.isAccessibilitySize {
        FoodEntryV2ReviewBottomBar(
          canSave: loggedTotals != nil && !didJustSave,
          didSave: didJustSave,
          addIdentifier: "savedFoodAdd",
          onSave: save,
          onDismiss: onDismiss
        )
      }
    }
  }

  private func save() {
    guard !didJustSave, let totals = finalTotals,
      let amount = NutritionInput.quantity(quantity, locale: locale), loggedTotals != nil
    else { return }
    let loggedFood = FoodItem(
      name: food.name + (isCustomizingMacros ? " (edited)" : ""),
      calories: totals.calories,
      proteinGrams: totals.protein,
      carbGrams: totals.carbs,
      fatGrams: totals.fat,
      servingDescription: food.servingDescription,
      sourceType: food.sourceType,
      menuItem: food.menuItem
    )
    let entry = DiaryEntry(
      date: date,
      mealType: mealType,
      foodItem: loggedFood,
      quantity: amount
    )
    modelContext.insert(loggedFood)
    modelContext.insert(entry)
    do {
      try modelContext.save()
      didJustSave = true
    } catch {
      modelContext.delete(entry)
      modelContext.delete(loggedFood)
      saveError = error.localizedDescription
    }
  }
}

#Preview {
  NavigationStack {
    SavedFoodDetailView(
      food: FoodItem(
        name: "Oatmeal", calories: 150, proteinGrams: 5, carbGrams: 27, fatGrams: 3,
        servingDescription: "1 cup", isSavedToLibrary: true)
    )
  }
  .modelContainer(for: [FoodItem.self, DiaryEntry.self], inMemory: true)
}
