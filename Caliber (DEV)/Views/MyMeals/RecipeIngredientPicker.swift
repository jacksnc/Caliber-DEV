import SwiftData
import SwiftUI
import UIKit

/// Browsing makes value snapshots only. The recipe editor decides whether to
/// save them later, so canceling this sheet never changes the food library.
struct RecipeIngredientPicker: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.locale) private var locale
  @Query(filter: #Predicate<FoodItem> { $0.isSavedToLibrary }, sort: \FoodItem.name)
  private var savedFoods: [FoodItem]
  @State private var query = ""
  @State private var results: [FoodCatalogEntry] = []
  @State private var isLoading = true
  @State private var searchError: String?
  @State private var didAdd = false

  var initialIngredient: RecipeIngredientDraft?
  let onAdd: (RecipeIngredientDraft) -> Void

  init(
    initialIngredient: RecipeIngredientDraft? = nil,
    onAdd: @escaping (RecipeIngredientDraft) -> Void
  ) {
    self.initialIngredient = initialIngredient
    self.onAdd = onAdd
  }

  private var matchingSavedFoods: [FoodItem] {
    let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return Array(
      savedFoods.lazy.filter { search.isEmpty || $0.name.localizedStandardContains(search) }
        .prefix(50))
  }

  var body: some View {
    NavigationStack {
      Group {
        if let initialIngredient {
          RecipeManualIngredientForm(
            initialIngredient: initialIngredient, onAdd: add)
        } else {
          List {
            Section {
              NavigationLink {
                RecipeManualIngredientForm(onAdd: add)
              } label: {
                Label("Enter Ingredient Manually", systemImage: "square.and.pencil")
                  .frame(minHeight: 48)
              }
              .accessibilityIdentifier("recipeManualIngredient")
            } footer: {
              Text(
                "Choose the food's preparation and your actual portion. Check a current label when available."
              )
            }

            if !matchingSavedFoods.isEmpty {
              Section("My Foods") {
                ForEach(matchingSavedFoods) { food in
                  NavigationLink {
                    RecipeSavedIngredientForm(
                      source: RecipeIngredientDraft(
                        name: food.name, servingDescription: food.servingDescription,
                        totals: MacroTotals(
                          calories: food.calories, protein: food.proteinGrams,
                          carbs: food.carbGrams, fat: food.fatGrams),
                        sourceType: food.sourceType),
                      onAdd: add)
                  } label: {
                    VStack(alignment: .leading, spacing: 4) {
                      Text(food.name)
                      Text(food.servingDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 48)
                  }
                  .accessibilityIdentifier("recipeIngredientSaved-\(food.id.uuidString)")
                }
              }
            }

            Section {
              if isLoading {
                ProgressView("Searching Offline Foods")
                  .frame(minHeight: 48)
              } else if let searchError {
                Text(searchError)
                  .foregroundStyle(.secondary)
              } else if results.isEmpty {
                Text(
                  "No matching offline foods. Try another name or enter the ingredient manually."
                )
                .foregroundStyle(.secondary)
              } else {
                ForEach(results) { entry in
                  NavigationLink {
                    RecipeCatalogIngredientForm(entry: entry, onAdd: add)
                  } label: {
                    VStack(alignment: .leading, spacing: 4) {
                      Text(entry.name)
                      Text(entry.sourceType.shortLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 48)
                  }
                  .accessibilityIdentifier("recipeIngredientCatalog-\(entry.id)")
                }
              }
            } header: {
              Text("Offline Foods")
            } footer: {
              Text(
                "Up to 50 matches are shown in each list. Search more specifically to narrow the results."
              )
            }
          }
          .searchable(text: $query, prompt: "Search foods or ingredients")
          .scrollDismissesKeyboard(.interactively)
          .navigationTitle("Choose Ingredient")
          .task(id: query) { await search(query) }
        }
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .frame(minHeight: 48)
        }
      }
    }
  }

  private func search(_ requestedQuery: String) async {
    guard !Task.isCancelled else { return }
    isLoading = true
    searchError = nil
    do {
      if !requestedQuery.isEmpty { try await Task.sleep(for: .milliseconds(150)) }
      try Task.checkCancellation()
      let service = await BundledFoodSearchService.prepared()
      try Task.checkCancellation()
      let matches = try service.catalogSearch(query: requestedQuery, limit: 50)
      guard !Task.isCancelled, query == requestedQuery else { return }
      results = matches
      isLoading = false
    } catch is CancellationError {
      // A newer search owns the visible result and loading state.
    } catch {
      guard !Task.isCancelled, query == requestedQuery else { return }
      results = []
      searchError =
        "Offline foods could not be opened. Use My Foods or enter an ingredient manually."
      isLoading = false
    }
  }

  private func add(_ ingredient: RecipeIngredientDraft) {
    guard !didAdd else { return }
    didAdd = true
    onAdd(ingredient)
    dismiss()
  }
}

private struct RecipeCatalogIngredientForm: View {
  @Environment(\.locale) private var locale
  @State private var grams = "100"
  @State private var didAdd = false
  let entry: FoodCatalogEntry
  let onAdd: (RecipeIngredientDraft) -> Void

  private var reference: FoodNutritionReference { .usda(entry) }
  private var draft: RecipeIngredientDraft? {
    guard let weight = NutritionInput.quantity(grams, locale: locale),
      let totals = try? reference.portionTotals(grams: weight), totals.isValid
    else { return nil }
    return RecipeIngredientDraft(
      name: entry.name,
      servingDescription:
        "\(NutritionInput.format(weight, locale: locale)) g · \(reference.sourceLabel) · \(entry.sourceType.shortLabel)",
      totals: totals, sourceType: reference.sourceType)
  }

  var body: some View {
    Form {
      Section {
        Text(entry.name)
        Text(reference.attribution)
          .font(.caption)
          .foregroundStyle(.secondary)
      } footer: {
        Text(reference.sourceNote)
      }
      Section {
        RecipeIngredientNumberField(
          label: "Grams", text: $grams, identifier: "recipeIngredientQuantity")
      } header: {
        Text("Ingredient Portion")
      } footer: {
        Text(
          "Enter a weight greater than zero. Nutrition is calculated from the source's 100 g values."
        )
      }
      if let draft {
        RecipeIngredientTotals(totals: draft.totals)
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .navigationTitle("Ingredient Portion")
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Add Ingredient") {
          guard !didAdd, let draft else { return }
          didAdd = true
          onAdd(draft)
        }
        .frame(minHeight: 48)
        .disabled(draft == nil || didAdd)
        .accessibilityIdentifier("ingredientAdd")
      }
      RecipeIngredientKeyboardToolbar()
    }
  }
}

private struct RecipeSavedIngredientForm: View {
  @Environment(\.locale) private var locale
  @State private var quantity = "1"
  @State private var didAdd = false
  let source: RecipeIngredientDraft
  let onAdd: (RecipeIngredientDraft) -> Void

  private var draft: RecipeIngredientDraft? {
    guard !source.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !source.servingDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      source.totals.isValid, let count = NutritionInput.quantity(quantity, locale: locale),
      source.totals.scaled(by: count).isValid
    else { return nil }
    var result = source
    result.quantity = count
    return result
  }

  var body: some View {
    Form {
      Section {
        Text(source.name)
        Text(source.servingDescription)
          .foregroundStyle(.secondary)
      } footer: {
        Text("Use the original saved portion. Changes here apply only to this recipe ingredient.")
      }
      Section {
        RecipeIngredientNumberField(
          label: "Number of Source Portions", text: $quantity,
          identifier: "recipeIngredientQuantity")
      } header: {
        Text("Ingredient Portion")
      } footer: {
        Text("Enter a portion count greater than zero. A half portion is 0.5.")
      }
      if let draft {
        RecipeIngredientTotals(totals: draft.totals.scaled(by: draft.quantity))
      } else {
        Section {
          Text(
            "This ingredient needs a valid portion and complete nutrition before it can be added."
          )
          .foregroundStyle(.secondary)
        }
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .navigationTitle("Ingredient Portion")
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Add Ingredient") {
          guard !didAdd, let draft else { return }
          didAdd = true
          onAdd(draft)
        }
        .frame(minHeight: 48)
        .disabled(draft == nil || didAdd)
        .accessibilityIdentifier("ingredientAdd")
      }
      RecipeIngredientKeyboardToolbar()
    }
  }
}

private struct RecipeManualIngredientForm: View {
  @Environment(\.locale) private var locale
  @State private var name: String
  @State private var serving: String
  @State private var calories: String
  @State private var protein: String
  @State private var carbs: String
  @State private var fat: String
  @State private var quantity: String
  @State private var didAdd = false
  let initialIngredient: RecipeIngredientDraft?
  let onAdd: (RecipeIngredientDraft) -> Void

  init(
    initialIngredient: RecipeIngredientDraft? = nil,
    onAdd: @escaping (RecipeIngredientDraft) -> Void
  ) {
    self.initialIngredient = initialIngredient
    self.onAdd = onAdd
    _name = State(initialValue: initialIngredient?.name ?? "")
    _serving = State(initialValue: initialIngredient?.servingDescription ?? "")
    _calories = State(
      initialValue: initialIngredient.map { NutritionInput.format($0.totals.calories) } ?? "")
    _protein = State(
      initialValue: initialIngredient.map { NutritionInput.format($0.totals.protein) } ?? "")
    _carbs = State(
      initialValue: initialIngredient.map { NutritionInput.format($0.totals.carbs) } ?? "")
    _fat = State(initialValue: initialIngredient.map { NutritionInput.format($0.totals.fat) } ?? "")
    _quantity = State(
      initialValue: initialIngredient.map { NutritionInput.format($0.quantity) } ?? "1")
  }

  private var draft: RecipeIngredientDraft? {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedServing = serving.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty, !trimmedServing.isEmpty,
      let totals = NutritionInput.totals(
        calories: calories, protein: protein, carbs: carbs, fat: fat, locale: locale),
      totals.isValid, let count = NutritionInput.quantity(quantity, locale: locale),
      totals.scaled(by: count).isValid
    else { return nil }
    let description =
      initialIngredient.map {
        let portion =
          trimmedServing == $0.servingDescription
          ? $0.servingDescription : $0.servingDescription + " · edited portion: " + trimmedServing
        return portion + (portion.contains("personal values") ? "" : " · personal values")
      } ?? trimmedServing
    return RecipeIngredientDraft(
      id: initialIngredient?.id ?? UUID(), name: trimmedName, servingDescription: description,
      totals: totals, quantity: count, sourceType: initialIngredient?.sourceType ?? .generic)
  }

  var body: some View {
    Form {
      Section("Ingredient") {
        TextField("Ingredient Name", text: $name)
          .frame(minHeight: 48)
          .accessibilityIdentifier("recipeIngredientName")
        TextField("Source Portion, e.g. 100 g or 1 piece", text: $serving)
          .frame(minHeight: 48)
          .accessibilityIdentifier("recipeIngredientServing")
      }
      Section {
        RecipeIngredientNumberField(
          label: "Calories", text: $calories, identifier: "recipeIngredientCalories")
        RecipeIngredientNumberField(
          label: "Protein (g)", text: $protein, identifier: "recipeIngredientProtein")
        RecipeIngredientNumberField(
          label: "Carbohydrates (g)", text: $carbs, identifier: "recipeIngredientCarbs")
        RecipeIngredientNumberField(
          label: "Fat (g)", text: $fat, identifier: "recipeIngredientFat")
      } header: {
        Text("Nutrition for One Source Portion")
      } footer: {
        Text("Enter all four values from the label for the portion above, including any zeros.")
      }
      Section("Amount Used in the Recipe") {
        RecipeIngredientNumberField(
          label: "Number of Source Portions", text: $quantity,
          identifier: "recipeIngredientQuantity")
      }
      if let draft {
        RecipeIngredientTotals(totals: draft.totals.scaled(by: draft.quantity))
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .navigationTitle("Manual Ingredient")
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Add Ingredient") {
          guard !didAdd, let draft else { return }
          didAdd = true
          onAdd(draft)
        }
        .frame(minHeight: 48)
        .disabled(draft == nil || didAdd)
        .accessibilityIdentifier("ingredientAdd")
      }
      RecipeIngredientKeyboardToolbar()
    }
  }
}

private struct RecipeIngredientNumberField: View {
  let label: String
  @Binding var text: String
  let identifier: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
      TextField(label, text: $text)
        .keyboardType(.decimalPad)
        .textFieldStyle(.roundedBorder)
        .frame(minHeight: 48)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
  }
}

private struct RecipeIngredientTotals: View {
  @Environment(\.locale) private var locale
  let totals: MacroTotals

  var body: some View {
    Section("Added to the Recipe") {
      Text("\(display(totals.calories)) calories")
        .accessibilityIdentifier("recipeIngredientPreviewCalories")
      Text(
        "Protein \(display(totals.protein)) g · Carbs \(display(totals.carbs)) g · Fat \(display(totals.fat)) g"
      )
      .font(.subheadline)
      .foregroundStyle(.secondary)
    }
  }

  private func display(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
  }
}

private struct RecipeIngredientKeyboardToolbar: ToolbarContent {
  var body: some ToolbarContent {
    ToolbarItemGroup(placement: .keyboard) {
      Spacer()
      Button("Done") {
        UIApplication.shared.sendAction(
          #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
      }
      .frame(minHeight: 48)
      .accessibilityIdentifier("recipeIngredientKeyboardDone")
    }
  }
}
