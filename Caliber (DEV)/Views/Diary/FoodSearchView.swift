//
//  FoodSearchView.swift
//  Caliber (DEV)
//

import SwiftData
import SwiftUI

/// One place to find an available food, saved meal, or restaurant item.
/// Each result opens the existing review form so logging creates a personal copy.
struct FoodSearchView: View {
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var modelContext
  @Query(filter: #Predicate<FoodItem> { $0.isSavedToLibrary }, sort: \FoodItem.name)
  private var savedFoods: [FoodItem]
  @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]
  @Query(sort: \Restaurant.name) private var restaurants: [Restaurant]

  private let searchService = BundledFoodSearchService()
  @State private var searchText = ""
  @State private var catalogFoods: [FoodCatalogEntry] = []
  @State private var isSearching = false
  @State private var isLoadingCatalog = false
  @State private var searchError: String?
  @State private var catalogError: String?
  @State private var isPresentingManualEntry = false

  private var query: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func matches(_ text: String) -> Bool {
    FoodSearchText.matches(text, query: query)
  }

  private var matchingSavedFoods: [FoodItem] {
    savedFoods.filter { matches($0.name) }
  }

  private var matchingMeals: [SavedMeal] {
    savedMeals.filter { meal in
      matches(meal.name) || meal.items.contains { matches($0.foodItem?.name ?? "") }
    }
  }

  private var matchingMenuItems: [MenuItem] {
    restaurants.flatMap(\.menuItems).filter { item in
      matches("\(item.restaurant?.name ?? "") \(item.name) \(item.category.displayName)")
    }
    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  private var matchingBuilders: [BuildableItemTemplate] {
    restaurants.flatMap(\.buildableTemplates).filter { template in
      matches("\(template.restaurant?.name ?? "") \(template.name)")
        || template.categories.contains { category in
          category.options.contains { matches($0.name) }
        }
    }
    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  private var hasResults: Bool {
    !catalogFoods.isEmpty || !matchingSavedFoods.isEmpty || !matchingMeals.isEmpty
      || !matchingMenuItems.isEmpty || !matchingBuilders.isEmpty
  }

  var body: some View {
    List {
      Section {
        NavigationLink {
          BarcodeFoodLookupView()
        } label: {
          Label("Scan a Barcode", systemImage: "barcode.viewfinder").frame(minHeight: 48)
        }.accessibilityIdentifier("openBarcode")
        Button {
          isPresentingManualEntry = true
        } label: {
          Label("Enter Food Manually", systemImage: "square.and.pencil")
        }
        NavigationLink {
          RestaurantListView()
        } label: {
          Label("Browse Restaurants", systemImage: "building.2")
        }
      } footer: {
        Text(
          "Search USDA foods offline, your saved foods and meals, and available restaurant menus. Check raw or cooked preparation before logging."
        )
      }

      if isSearching || isLoadingCatalog {
        ProgressView("Finding foods…")
      }

      if let searchError {
        Section {
          Label(searchError, systemImage: "exclamationmark.triangle")
          Button("Retry Food Search") { Task { await searchFoods() } }
        }
      }

      if let catalogError {
        Section {
          Label(catalogError, systemImage: "exclamationmark.triangle")
          Button("Retry Restaurant Loading") { Task { await loadCatalog() } }
        }
      }

      if !matchingSavedFoods.isEmpty {
        Section("My Foods") {
          ForEach(matchingSavedFoods) { food in
            foodLink(food)
          }
        }
      }

      if !matchingMeals.isEmpty {
        Section("My Meals") {
          ForEach(matchingMeals) { meal in
            NavigationLink {
              SavedMealDetailView(meal: meal)
            } label: {
              VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                Text("\(meal.items.count) foods")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
      }

      if !catalogFoods.isEmpty {
        Section("USDA Foods") {
          ForEach(catalogFoods) { food in
            NavigationLink {
              FoodNutritionReviewView(reference: .usda(food))
            } label: {
              VStack(alignment: .leading, spacing: 3) {
                Text(food.name)
                Text(
                  "100 g · \(NutritionInput.format(food.nutritionPer100g.calories, locale: locale)) cal · USDA"
                )
                .font(.caption).foregroundStyle(.secondary)
              }.frame(minHeight: 48)
            }.accessibilityIdentifier("catalogFood-\(food.fdcID)")
          }
        }
      }

      if !matchingBuilders.isEmpty {
        Section("Build a Restaurant Meal") {
          ForEach(matchingBuilders) { template in
            NavigationLink {
              BuildYourOwnView(template: template)
            } label: {
              VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                Text(template.restaurant?.name ?? "Restaurant")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
      }

      if !matchingMenuItems.isEmpty {
        Section("Restaurant Menu Items") {
          ForEach(matchingMenuItems) { item in
            NavigationLink {
              MenuItemDetailView(menuItem: item)
            } label: {
              VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                Text(
                  "\(item.restaurant?.name ?? "Restaurant") · \(item.category.displayName) · \(NutritionInput.format(item.baseCalories, locale: locale)) cal"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
              }
            }
          }
        }
      }

      if !hasResults && !isSearching && !isLoadingCatalog
        && searchError == nil && catalogError == nil
      {
        ContentUnavailableView(
          "No Foods Found",
          systemImage: "magnifyingglass",
          description: Text("Try another name or enter your food manually.")
        )
      }
    }
    .navigationTitle("Search Foods")
    .accessibilityIdentifier("foodSearchScreen")
    .searchable(
      text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
      prompt: "Search foods, meals, or restaurants"
    )
    .task(id: query) {
      await searchFoods()
    }
    .task {
      await loadCatalog()
    }
    .sheet(isPresented: $isPresentingManualEntry) {
      AddFoodView(mealType: .snack, date: .now)
        .presentationDragIndicator(.visible)
    }
  }

  private func foodLink(_ food: FoodItem) -> some View {
    NavigationLink {
      SavedFoodDetailView(food: food)
    } label: {
      VStack(alignment: .leading, spacing: 2) {
        Text(food.name)
        Text(
          "\(food.servingDescription) · \(NutritionInput.format(food.calories, locale: locale)) cal"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
  }

  private func searchFoods() async {
    isSearching = true
    searchError = nil
    do {
      let results = try searchService.catalogSearch(query: query, limit: 50)
      // A newer query may finish before an older, canceled request.
      try Task.checkCancellation()
      catalogFoods = results
      isSearching = false
    } catch is CancellationError {
      // The replacement search owns the loading state.
    } catch {
      guard !Task.isCancelled else { return }
      catalogFoods = []
      searchError = "The offline food catalog could not be opened. You can enter a food manually."
      isSearching = false
    }
  }

  private func loadCatalog() async {
    isLoadingCatalog = true
    catalogError = nil
    defer { isLoadingCatalog = false }
    do {
      try await RestaurantCatalogSeeder.seedIfNeeded(in: modelContext)
    } catch is CancellationError {
      // Leaving this screen can cancel its initial load.
    } catch {
      catalogError = error.localizedDescription
    }
  }
}

#Preview {
  FoodSearchView()
    .modelContainer(
      for: [FoodItem.self, DiaryEntry.self, SavedMeal.self, Restaurant.self], inMemory: true)
}
