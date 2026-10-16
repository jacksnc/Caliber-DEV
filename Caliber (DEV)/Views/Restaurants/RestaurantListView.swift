import CaliberDatabase
import SwiftData
import SwiftUI

//
//  RestaurantListView.swift
//  Caliber (DEV)
//

/// Search restaurants, then browse each restaurant's fixed menu categories.
struct RestaurantListView: View {
  @EnvironmentObject private var runtime: FoundationRuntime
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Restaurant.name) private var restaurants: [Restaurant]

  let mealType: MealType
  let date: Date
  init(mealType: MealType = .snack, date: Date = .now) {
    self.mealType = mealType
    self.date = date
  }

  @State private var importedCatalog: RestaurantMenuCatalog?
  @State private var importError: String?
  @State private var searchText = ""
  @State private var loadError: String?
  @State private var isLoading = false
  @State private var isAddingRestaurant = false

  private var filteredRestaurants: [Restaurant] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return restaurants }
    return restaurants.filter { FoodSearchText.matches($0.name, query: query) }
  }

  var body: some View {
    List {
      if let importedCatalog {
        if importedCatalog.restaurants.isEmpty {
          Section("Imported Menus") {
            Text(
              "New restaurant menus are pending an approved data source. Sample menus and your custom items are available below."
            ).font(.footnote)
              .accessibilityIdentifier("restaurantSourcePending")
          }
        } else {
          Section(importedCatalog.fictional ? "Fictional Test Menus" : "Imported Menus") {
            ForEach(
              importedCatalog.restaurants.filter {
                FoodSearchText.matches($0.name, query: searchText)
              }, id: \.id
            ) { restaurant in
              if let source = importedCatalog.sources.first(where: { $0.id == restaurant.sourceID })
              {
                NavigationLink(restaurant.name) {
                  ImportedRestaurantMenuView(
                    restaurant: restaurant, source: source, fictional: importedCatalog.fictional,
                    mealType: mealType, date: date)
                }.accessibilityIdentifier("importedRestaurant-" + restaurant.id)
              }
            }
          }
        }
      }
      if let importError { Section { Text(importError).font(.footnote) } }

      if let loadError {
        Section {
          Label(loadError, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.secondary)
          Button("Try Again") {
            Task { await loadCatalog() }
          }
        }
      }

      if isLoading && restaurants.isEmpty {
        ProgressView("Loading restaurants…")
      } else if filteredRestaurants.isEmpty && loadError == nil {
        ContentUnavailableView.search(text: searchText)
      } else {
        Section {
          ForEach(filteredRestaurants) { restaurant in
            NavigationLink {
              RestaurantDetailView(restaurant: restaurant, mealType: mealType, date: date)
            } label: {
              VStack(alignment: .leading, spacing: 3) {
                Text(restaurant.name)
                Text(
                  "\(restaurant.menuItems.count) items · \(restaurant.buildableTemplates.count) builders"
                )
                .font(.caption).foregroundStyle(.secondary)
              }.frame(minHeight: 48)
            }
            .accessibilityLabel(restaurant.name)
            .accessibilityValue(
              "\(restaurant.menuItems.count) menu items and \(restaurant.buildableTemplates.count) builders"
            )
          }
        } footer: {
          Text("Sample menus for now. These are not complete, verified restaurant menus.")
        }
      }
    }
    .navigationTitle("Restaurants")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          isAddingRestaurant = true
        } label: {
          Label("Add Restaurant", systemImage: "plus")
        }
        .accessibilityIdentifier("addRestaurant").disabled(isLoading)
      }
    }
    .sheet(isPresented: $isAddingRestaurant) { AddRestaurantView() }
    .searchable(text: $searchText, prompt: "Search restaurants")
    .task {
      await loadCatalog()
      do {
        importedCatalog = try await BundledRestaurantMenuService.load(testing: runtime.testing)
      } catch {
        importError =
          "Imported menus could not be opened. Sample menus and custom items remain available."
      }
    }
  }

  private func loadCatalog() async {
    isLoading = true
    loadError = nil
    defer { isLoading = false }
    do {
      try await RestaurantCatalogSeeder.seedIfNeeded(in: modelContext)
    } catch is CancellationError {
      // Leaving this screen can cancel its initial load.
    } catch {
      loadError = error.localizedDescription
    }
  }
}

#Preview {
  NavigationStack {
    RestaurantListView()
  }
  .modelContainer(
    for: [Restaurant.self, MenuItem.self, BuildableItemTemplate.self], inMemory: true)
}
