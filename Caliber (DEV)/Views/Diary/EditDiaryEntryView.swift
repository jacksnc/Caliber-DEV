import SwiftUI
import SwiftData

/// Uses a temporary form draft so Cancel never changes the stored diary entry.
struct EditDiaryEntryView: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let entry: DiaryEntry

    @State private var name: String
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var quantity: String
    @State private var mealType: MealType
    @State private var date: Date
    @State private var saveError: String?
    @State private var preparedLocale = false

    init(entry: DiaryEntry) {
        self.entry = entry
        let food = entry.foodItem
        _name = State(initialValue: food?.name ?? "")
        _calories = State(initialValue: NutritionInput.format(food?.calories ?? 0))
        _protein = State(initialValue: NutritionInput.format(food?.proteinGrams ?? 0))
        _carbs = State(initialValue: NutritionInput.format(food?.carbGrams ?? 0))
        _fat = State(initialValue: NutritionInput.format(food?.fatGrams ?? 0))
        _quantity = State(initialValue: NutritionInput.format(entry.quantity))
        _mealType = State(initialValue: entry.mealType)
        _date = State(initialValue: entry.date)
    }

    private var perServingTotals: MacroTotals? {
        NutritionInput.totals(calories: calories, protein: protein, carbs: carbs, fat: fat, locale: locale)
    }

    private var entryTotals: MacroTotals? {
        guard let totals = perServingTotals,
              let quantity = NutritionInput.quantity(quantity, locale: locale) else { return nil }
        let scaled = totals.scaled(by: quantity)
        guard [scaled.calories, scaled.protein, scaled.carbs, scaled.fat].allSatisfy(\.isFinite) else {
            return nil
        }
        return scaled
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && entryTotals != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    LabeledContent("Serving", value: entry.foodItem?.servingDescription ?? "1 serving")
                    LabeledContent("Quantity") { TextField("Quantity", text: $quantity).multilineTextAlignment(.trailing) }
                        .keyboardType(.decimalPad)
                }

                Section {
                    LabeledContent("Calories") { TextField("Calories", text: $calories).multilineTextAlignment(.trailing) }
                        .keyboardType(.decimalPad)
                    LabeledContent("Protein (g)") { TextField("Protein (g)", text: $protein).multilineTextAlignment(.trailing) }
                        .keyboardType(.decimalPad)
                    LabeledContent("Carbs (g)") { TextField("Carbs (g)", text: $carbs).multilineTextAlignment(.trailing) }
                        .keyboardType(.decimalPad)
                    LabeledContent("Fat (g)") { TextField("Fat (g)", text: $fat).multilineTextAlignment(.trailing) }
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Macros per serving")
                } footer: {
                    Text("These changes apply only to this diary entry. Saved foods and restaurant menus stay the same.")
                }

                if let totals = entryTotals {
                    Section("Total for this entry") {
                        Text("\(NutritionInput.format(totals.calories, locale: locale)) calories")
                            .font(.headline)
                        Text("Protein \(NutritionInput.format(totals.protein, locale: locale))g · Carbs \(NutritionInput.format(totals.carbs, locale: locale))g · Fat \(NutritionInput.format(totals.fat, locale: locale))g")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Meal") {
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                if !canSave {
                    Section {
                        Text("Enter a food name, nonnegative nutrition values, and a quantity greater than zero.")
                            .foregroundStyle(.secondary)
                    }
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .foregroundStyle(.red)
                    }
                }
            }
            .onAppear {
                guard !preparedLocale else { return }
                calories = NutritionInput.reformatted(calories, from: .current, to: locale)
                protein = NutritionInput.reformatted(protein, from: .current, to: locale)
                carbs = NutritionInput.reformatted(carbs, from: .current, to: locale)
                fat = NutritionInput.reformatted(fat, from: .current, to: locale)
                quantity = NutritionInput.reformatted(quantity, from: .current, to: locale)
                preparedLocale = true
            }
            .navigationTitle("Edit Food")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard canSave, let totals = perServingTotals,
              let quantity = NutritionInput.quantity(quantity, locale: locale) else { return }
        do {
            try DiaryEntryEditor.save(
                entry: entry,
                name: name,
                totals: totals,
                quantity: quantity,
                mealType: mealType,
                date: date,
                in: modelContext
            )
            dismiss()
        } catch {
            saveError = "Couldn't save your changes. \(error.localizedDescription)"
        }
    }
}
