//
//  MyFoodsView.swift
//  Caliber (DEV)
//

import HeliosDesign
import SwiftData
import SwiftUI

/// The Food Library's "My Foods" folder: every standalone food the user has
/// chosen to save for reuse (see the "Save to My Foods" toggle in
/// AddFoodView). Tapping one logs it again without retyping its macros.
struct MyFoodsView: View {
  @Environment(\.locale) private var locale
  @Query(filter: #Predicate<FoodItem> { $0.isSavedToLibrary }, sort: \FoodItem.name)
  private var savedFoods: [FoodItem]

  let mealType: MealType
  let date: Date

  @State private var searchText = ""
  @State private var manualEntryRequest: FoodEntryPass2ManualRequest?
  @State private var quickReviewTarget: FoodEntryPass2QuickReviewTarget?

  init(mealType: MealType = .snack, date: Date = .now) {
    self.mealType = mealType
    self.date = date
  }

  private var query: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var filteredFoods: [FoodItem] {
    guard !query.isEmpty else { return savedFoods }
    let exact = savedFoods.filter {
      FoodSearchText.matches($0.name + " " + $0.servingDescription, query: query)
    }
    if !exact.isEmpty { return exact }
    return savedFoods.filter {
      FoodSearchText.fuzzyMatches($0.name + " " + $0.servingDescription, query: query)
    }
  }

  var body: some View {
    List {
      Group {
        if savedFoods.isEmpty {
          Section {
            FoodEntryPass2EmptyStateCard(
              title: "No Saved Foods Yet",
              symbol: "carrot",
              message:
                "Create a personal food once to reuse its portion and macros anytime.",
              query: "",
              showsSearchAllAction: false,
              onSearchAll: {},
              onCreateManualFood: { openManualEntry(prefillName: nil) }
            )
            .caliberCardRow()
          }
        } else if filteredFoods.isEmpty {
          Section {
            FoodEntryPass2EmptyStateCard(
              title: "No Matching Saved Foods",
              symbol: "magnifyingglass",
              message: "Try another name or create this food manually for \(mealType.displayName).",
              query: query,
              showsSearchAllAction: false,
              onSearchAll: {},
              onCreateManualFood: { openManualEntry(prefillName: query) }
            )
            .caliberCardRow()
          }
        } else {
          Section {
            ForEach(filteredFoods) { food in
              foodRow(food)
            }
          }
        }
      }
      .listRowBackground(CaliberRowBackground())
    }
    .caliberScreen()
    .navigationTitle("My Foods")
    .toolbar(.visible, for: .navigationBar)
    .searchable(text: $searchText, prompt: "Search")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          openManualEntry(prefillName: query.isEmpty ? nil : query)
        } label: {
          Label("Add Food", systemImage: "plus")
        }
        .accessibilityIdentifier("myFoodsCreateFood")
      }
    }
    .sheet(item: $manualEntryRequest) { request in
      AddFoodView(mealType: mealType, date: date, prefill: request.prefill)
        .presentationDragIndicator(.visible)
    }
    .sheet(item: $quickReviewTarget) { target in
      FoodEntryPass2QuickReviewSheet(target: target, mealType: mealType, date: date)
    }
  }

  private func foodRow(_ food: FoodItem) -> some View {
    HStack(spacing: HeliosTokens.space(2)) {
      NavigationLink {
        SavedFoodDetailView(food: food, mealType: mealType, date: date)
      } label: {
        VStack(alignment: .leading, spacing: 3) {
          Text(food.name)
          Text(
            "\(food.servingDescription) · \(NutritionInput.format(food.calories, locale: locale)) cal · \(NutritionInput.format(food.proteinGrams, locale: locale))p \(NutritionInput.format(food.carbGrams, locale: locale))c \(NutritionInput.format(food.fatGrams, locale: locale))f"
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        .frame(minHeight: 48)
      }
      .accessibilityIdentifier("myFood-\(food.id.uuidString)")

      FoodEntryPass2QuickReviewButton(
        foodName: food.name,
        identifier: "foodEntryQuickReview-myFood-\(food.id.uuidString)"
      ) {
        quickReviewTarget = .savedFood(
          key: "myFood-\(food.id.uuidString)",
          food: food,
          quantity: 1
        )
      }
    }
  }

  private func openManualEntry(prefillName: String?) {
    let trimmed = prefillName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let prefill =
      trimmed.isEmpty
      ? nil
      : FoodEntryPrefill(
        name: trimmed,
        servingDescription: "",
        calories: "",
        protein: "",
        carbs: "",
        fat: ""
      )
    manualEntryRequest = FoodEntryPass2ManualRequest(prefill: prefill)
  }
}

#Preview {
  NavigationStack {
    MyFoodsView()
  }
  .modelContainer(for: [FoodItem.self, DiaryEntry.self], inMemory: true)
  .environmentObject(
    FoodLibraryPreferences(defaults: UserDefaults(suiteName: "Caliber.Food.Previews")!))
}
