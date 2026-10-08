//
//  MacroOverrideSection.swift
//  Caliber (DEV)
//

import SwiftUI

/// A reusable "adjust macros just for this log" section: lets the user
/// temporarily override an item's macros without changing the saved
/// FoodItem/MenuItem it came from. Used by any screen that logs a library
/// item (restaurant menu items, saved "My Foods").
struct MacroOverrideSection: View {
    let itemName: String
    let baseTotals: MacroTotals
    @Binding var isEditing: Bool
    @Binding var calories: String
    @Binding var protein: String
    @Binding var carbs: String
    @Binding var fat: String

    var body: some View {
        Section {
            Toggle("Adjust macros for this log", isOn: $isEditing)
                .onChange(of: isEditing) { _, isOn in
                    if isOn {
                        calories = NutritionInput.format(baseTotals.calories)
                        protein = NutritionInput.format(baseTotals.protein)
                        carbs = NutritionInput.format(baseTotals.carbs)
                        fat = NutritionInput.format(baseTotals.fat)
                    }
                }

            if isEditing {
                LabeledContent("Calories") { TextField("Calories", text: $calories).multilineTextAlignment(.trailing) }
                    .keyboardType(.decimalPad)
                LabeledContent("Protein (g)") { TextField("Protein (g)", text: $protein).multilineTextAlignment(.trailing) }
                    .keyboardType(.decimalPad)
                LabeledContent("Carbs (g)") { TextField("Carbs (g)", text: $carbs).multilineTextAlignment(.trailing) }
                    .keyboardType(.decimalPad)
                LabeledContent("Fat (g)") { TextField("Fat (g)", text: $fat).multilineTextAlignment(.trailing) }
                    .keyboardType(.decimalPad)
            }
        } header: {
            Text("Adjust Nutrition (per serving)")
        } footer: {
            if isEditing {
                Text("These changes apply only to this diary entry. \(itemName) in the library won't change.")
            }
        }
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
