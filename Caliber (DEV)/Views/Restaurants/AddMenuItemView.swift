import SwiftData
import SwiftUI

/// A temporary draft used for both creating and editing a personal menu item.
/// Cancel leaves the saved menu alone; Save commits only this item's changes.
struct AddMenuItemView: View {
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  let restaurant: Restaurant
  let item: MenuItem?

  @State private var name: String
  @State private var category: MenuCategory
  @State private var calories: String
  @State private var protein: String
  @State private var carbs: String
  @State private var fat: String
  @State private var saveError: String?
  @State private var preparedLocale = false

  init(restaurant: Restaurant, item: MenuItem? = nil) {
    self.restaurant = restaurant
    self.item = item
    _name = State(initialValue: item?.name ?? "")
    _category = State(initialValue: item?.category ?? .entree)
    _calories = State(initialValue: item.map { NutritionInput.format($0.baseCalories) } ?? "")
    _protein = State(initialValue: item.map { NutritionInput.format($0.baseProtein) } ?? "0")
    _carbs = State(initialValue: item.map { NutritionInput.format($0.baseCarbs) } ?? "0")
    _fat = State(initialValue: item.map { NutritionInput.format($0.baseFat) } ?? "0")
  }

  private var totals: MacroTotals? {
    NutritionInput.totals(
      calories: calories, protein: protein, carbs: carbs, fat: fat, locale: locale)
  }

  private var canSave: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && totals != nil && (item == nil || item?.isCustom == true)
  }

  var body: some View {
    NavigationStack {
      Form {
        Group {
          Section("Item") {
            TextField("Item name", text: $name)
              .accessibilityIdentifier("customMenuItemName")
            Picker("Category", selection: $category) {
              ForEach(MenuCategory.displayOrder) { category in
                Text(category.displayName).tag(category)
              }
            }
          }

          Section {
            LabeledContent("Calories") {
              TextField("Calories", text: $calories)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
            LabeledContent("Protein (g)") {
              TextField("Protein (g)", text: $protein)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
            LabeledContent("Carbs (g)") {
              TextField("Carbs (g)", text: $carbs)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
            LabeledContent("Fat (g)") {
              TextField("Fat (g)", text: $fat)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
          } header: {
            Text("Nutrition per item")
          } footer: {
            Text(
              "Saved to your \(restaurant.name) menu. Editing this item won't change foods you've already logged."
            )
          }

          if let saveError {
            Section { Text(saveError).foregroundStyle(.red) }
          }
        }
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen()
      .onAppear {
        guard !preparedLocale else { return }
        calories = NutritionInput.reformatted(calories, from: .current, to: locale)
        protein = NutritionInput.reformatted(protein, from: .current, to: locale)
        carbs = NutritionInput.reformatted(carbs, from: .current, to: locale)
        fat = NutritionInput.reformatted(fat, from: .current, to: locale)
        preparedLocale = true
      }
      .navigationTitle(item == nil ? "New Custom Item" : "Edit Custom Item")
      .navigationBarTitleDisplayMode(.inline)
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
    guard canSave, let totals else { return }
    do {
      try CustomMenuItemEditor.save(
        item: item, restaurant: restaurant, name: name,
        category: category, totals: totals, in: modelContext
      )
      dismiss()
    } catch {
      saveError = "Couldn't save this item. \(error.localizedDescription)"
    }
  }
}

#Preview {
  AddMenuItemView(restaurant: Restaurant(name: "Longhorn Steakhouse"))
    .modelContainer(for: [Restaurant.self, MenuItem.self], inMemory: true)
}
