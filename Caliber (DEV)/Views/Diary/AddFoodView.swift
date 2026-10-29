//
//  AddFoodView.swift
//  Caliber (DEV)
//

import HeliosDesign
import SwiftData
import SwiftUI
import UIKit

/// Compact manual-entry form for logging a personal food to a specific meal and day.
/// Requires all four nutrition values rather than silently inventing 0 g for blank macros.
struct AddFoodView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var modelContext
  @Environment(\.heliosTheme) private var theme

  @State private var mealType: MealType
  @State private var date: Date
  @State private var draft: FoodEntryPass2ManualDraft
  @State private var lastSavedMeal: MealType?
  @State private var saveError: String?
  @State private var preparedLocale = false

  /// `prefill` comes from a scanned label, search query, or confirmed estimate; every field stays editable.
  init(mealType: MealType, date: Date, prefill: FoodEntryPrefill? = nil) {
    _mealType = State(initialValue: mealType)
    _date = State(initialValue: date)
    _draft = State(initialValue: FoodEntryPass2ManualDraft(prefill: prefill))
  }

  private var scaledTotals: MacroTotals? {
    draft.scaledTotals(locale: locale)
  }

  private var canSave: Bool {
    draft.canSave(locale: locale)
  }

  var body: some View {
    NavigationStack {
      Form {
        Group {
          foodSection
          macrosSection
          previewSection
          destinationSection
          savedConfirmationSection
        }
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen()
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle("Add Food")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        if !typeSize.isAccessibilitySize {
          ToolbarItem(placement: .cancellationAction) {
            Button(lastSavedMeal == nil ? "Cancel" : "Done") {
              dismiss()
            }
            .frame(minHeight: 48)
            .accessibilityIdentifier("manualFoodCancel")
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save", action: save)
              .disabled(!canSave)
              .frame(minHeight: 48)
              .accessibilityIdentifier("manualFoodSave")
          }
        }
        ToolbarItem(placement: .keyboard) {
          Button("Done") {
            UIApplication.shared.sendAction(
              #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
          }
          .frame(minHeight: 48)
          .accessibilityIdentifier("manualFoodKeyboardDone")
        }
      }
      .safeAreaInset(edge: .bottom) {
        if typeSize.isAccessibilitySize {
          VStack(spacing: 8) {
            Button(action: save) {
              Text("Save")
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(
              canSave ? theme.palette.accent.base.color : theme.palette.text.secondary.color
            )
            .disabled(!canSave)
            .accessibilityIdentifier("manualFoodSave")

            Button {
              dismiss()
            } label: {
              Text(lastSavedMeal == nil ? "Cancel" : "Done")
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.palette.text.primary.color)
            .accessibilityIdentifier("manualFoodCancel")
          }
          .padding(.horizontal)
          .padding(.vertical, 8)
          .background(.bar)
        }
      }
      .alert(
        "Couldn't Save Food",
        isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
      ) {
        Button("OK", role: .cancel) { saveError = nil }
      } message: {
        Text(saveError ?? "Please try again.")
      }
      .onAppear {
        guard !preparedLocale else { return }
        draft.quantity = NutritionInput.reformatted(draft.quantity, from: .current, to: locale)
        preparedLocale = true
      }
      .onChange(of: draft) { _, _ in
        if !draft.trimmedName.isEmpty || draft.hasAnyMacroText {
          lastSavedMeal = nil
        }
      }
    }
  }

  private var foodSection: some View {
    Section {
      VStack(alignment: .leading, spacing: 4) {
        Text("Name")
          .heliosFont(.caption)
          .foregroundStyle(theme.palette.text.secondary.color)
        TextField("Name", text: $draft.name)
          .frame(maxWidth: .infinity, minHeight: 48)
          .accessibilityIdentifier("manualFoodName")
      }
      VStack(alignment: .leading, spacing: 4) {
        Text("Serving (e.g. 1 cup)")
          .heliosFont(.caption)
          .foregroundStyle(theme.palette.text.secondary.color)
        TextField("Serving", text: $draft.servingDescription)
          .frame(maxWidth: .infinity, minHeight: 48)
          .accessibilityIdentifier("manualFoodServing")
      }
      VStack(alignment: .leading, spacing: 4) {
        Text("Quantity")
          .heliosFont(.caption)
          .foregroundStyle(theme.palette.text.secondary.color)
        TextField("Quantity", text: $draft.quantity)
          .keyboardType(.decimalPad)
          .frame(maxWidth: .infinity, minHeight: 48)
          .accessibilityIdentifier("manualFoodQuantity")
      }
      Toggle("Save to My Foods", isOn: $draft.saveToLibrary)
        .accessibilityIdentifier("manualFoodSaveToLibrary")
    } header: {
      Text("Food & Portion")
    }
  }

  private var macrosSection: some View {
    Section {
      macroField("Calories", placeholder: "Calories", text: $draft.calories)
      macroField("Protein (g)", placeholder: "Protein", text: $draft.protein)
      macroField("Carbs (g)", placeholder: "Carbs", text: $draft.carbs)
      macroField("Fat (g)", placeholder: "Fat", text: $draft.fat)
    } header: {
      Text("Macros (per serving)")
    } footer: {
      Text("Enter all four values from the label or recipe, including 0 when a macro is 0 g.")
        .accessibilityIdentifier("manualFoodValidationNote")
    }
  }

  private func macroField(_ title: String, placeholder: String, text: Binding<String>) -> some View
  {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .heliosFont(.caption)
        .foregroundStyle(theme.palette.text.secondary.color)
      TextField(placeholder, text: text)
        .keyboardType(.decimalPad)
        .frame(maxWidth: .infinity, minHeight: 48)
    }
  }

  @ViewBuilder
  private var previewSection: some View {
    if let totals = scaledTotals {
      Section {
        Text("\(NutritionInput.format(totals.calories, locale: locale)) calories")
          .heliosFont(.section)
          .foregroundStyle(theme.palette.text.primary.color)
          .accessibilityIdentifier("manualFoodTotalCalories")
        FoodEntryPass2MacroSummaryRow(totals: totals)
      } header: {
        Text("Nutrition for This Log")
      }
    }
  }

  private var destinationSection: some View {
    Section {
      Picker("Meal", selection: $mealType) {
        ForEach(MealType.allCases) { meal in
          Text(meal.displayName).tag(meal)
        }
      }
      .accessibilityIdentifier("manualFoodMeal")
      DatePicker("Date", selection: $date, displayedComponents: .date)
        .accessibilityIdentifier("manualFoodDate")
    } header: {
      Text("Destination")
    }
  }

  @ViewBuilder
  private var savedConfirmationSection: some View {
    if let savedMeal = lastSavedMeal {
      Section {
        Label("Added to \(savedMeal.displayName)", systemImage: "checkmark.circle.fill")
          .foregroundStyle(theme.palette.status.success.color)
          .accessibilityIdentifier("manualFoodSaved")
      }
    }
  }

  private func save() {
    do {
      try FoodEntryPass2ManualLogger.log(
        draft: draft,
        mealType: mealType,
        date: date,
        locale: locale,
        in: modelContext
      )
      let savedMeal = mealType
      draft = FoodEntryPass2ManualDraft(saveToLibrary: draft.saveToLibrary)
      draft.quantity = NutritionInput.reformatted(draft.quantity, from: .current, to: locale)
      lastSavedMeal = savedMeal
    } catch {
      saveError = error.localizedDescription
    }
  }
}

#Preview {
  AddFoodView(mealType: .breakfast, date: .now)
    .modelContainer(for: [FoodItem.self, DiaryEntry.self], inMemory: true)
}
