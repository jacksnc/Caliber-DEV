//
//  RestaurantListView.swift
//  Caliber (DEV)
//

import SwiftData
import SwiftUI

/// Search restaurants, then browse each restaurant's fixed menu categories.
struct RestaurantListView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Restaurant.name) private var restaurants: [Restaurant]

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
              RestaurantDetailView(restaurant: restaurant)
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
