//
//  MacroOverrideSection.swift
//  Caliber (DEV)
//

import HeliosDesign
import SwiftUI

/// A reusable "adjust macros just for this log" section: lets the user
/// temporarily override an item's macros without changing the saved
/// FoodItem/MenuItem it came from. Used by any screen that logs a library
/// item (restaurant menu items, saved "My Foods").
struct MacroOverrideSection: View {
  private enum Field: Hashable {
    case calories
    case protein
    case carbs
    case fat
  }

  @Environment(\.heliosTheme) private var theme
  @Environment(\.locale) private var locale
  @FocusState private var focusedField: Field?
  let itemName: String
  let baseTotals: MacroTotals
  var basisLabel: String = "per serving"
  @Binding var isEditing: Bool
  @Binding var calories: String
  @Binding var protein: String
  @Binding var carbs: String
  @Binding var fat: String

  var body: some View {
    let data = theme.palette.data
    Section {
      Toggle("Adjust macros for this log", isOn: $isEditing)
        .frame(minHeight: 48)
        .onChange(of: isEditing) { _, isOn in
          if isOn {
            resetToSourceValues()
          }
        }

      if isEditing {
        macroField(
          title: "Calories",
          placeholder: "Calories",
          field: .calories,
          color: data.energy.color,
          text: $calories
        )
        macroField(
          title: "Protein (g)",
          placeholder: "Protein (g)",
          field: .protein,
          color: data.protein.color,
          text: $protein
        )
        macroField(
          title: "Carbs (g)",
          placeholder: "Carbs (g)",
          field: .carbs,
          color: data.carbs.color,
          text: $carbs
        )
        macroField(
          title: "Fat (g)",
          placeholder: "Fat (g)",
          field: .fat,
          color: data.fat.color,
          text: $fat
        )

        Button(action: resetToSourceValues) {
          Label("Reset to Source Values", systemImage: "arrow.counterclockwise")
            .heliosFont(.callout)
            .foregroundStyle(theme.palette.accent.base.color)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("macroOverrideReset")
      }
    } header: {
      Text("Adjust Nutrition (\(basisLabel))")
    } footer: {
      if isEditing {
        Text(
          "Enter calories, protein, carbs and fat \(basisLabel). These changes apply only to this diary entry—\(itemName) in the library won't change."
        )
      }
    }
  }

  private func resetToSourceValues() {
    calories = NutritionInput.format(baseTotals.calories, locale: locale)
    protein = NutritionInput.format(baseTotals.protein, locale: locale)
    carbs = NutritionInput.format(baseTotals.carbs, locale: locale)
    fat = NutritionInput.format(baseTotals.fat, locale: locale)
  }

  private func macroField(
    title: LocalizedStringKey,
    placeholder: String,
    field: Field,
    color: Color,
    text: Binding<String>
  ) -> some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(1)) {
      HStack(spacing: 6) {
        Circle()
          .fill(color)
          .frame(width: 8, height: 8)
          .accessibilityHidden(true)
        Text(title)
          .heliosFont(.caption)
          .foregroundStyle(theme.palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
      }
      HStack {
        TextField(placeholder, text: text)
          .keyboardType(.decimalPad)
          .monospacedDigit()
          .focused($focusedField, equals: field)
          .frame(maxWidth: .infinity, minHeight: 48)
      }
      .padding(.horizontal, HeliosTokens.space(3))
      .frame(maxWidth: .infinity, minHeight: 48)
      .background {
        FoodEntryV2Surface(level: .raised, cornerRadius: HeliosTokens.radius.button)
      }
      .contentShape(Rectangle())
      .onTapGesture {
        focusedField = field
      }
    }
    .padding(.vertical, 2)
  }
}

#Preview {
  @Previewable @State var isEditing = false
  @Previewable @State var calories = ""
  @Previewable @State var protein = ""
  @Previewable @State var carbs = ""
  @Previewable @State var fat = ""

  Form {
    MacroOverrideSection(
      itemName: "Flo's Filet",
      baseTotals: MacroTotals(calories: 300, protein: 36, carbs: 0, fat: 17),
      isEditing: $isEditing,
      calories: $calories,
      protein: $protein,
      carbs: $carbs,
      fat: $fat
    )
  }
}
