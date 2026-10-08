//
//  RestaurantListView.swift
//  Caliber (DEV)
//

import SwiftUI
import SwiftData

/// Search restaurants, then browse each restaurant's fixed menu categories.
struct RestaurantListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Restaurant.name) private var restaurants: [Restaurant]

    @State private var searchText = ""
    @State private var loadError: String?
    @State private var isLoading = false

    private var filteredRestaurants: [Restaurant] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return restaurants }
        return restaurants.filter { $0.name.localizedCaseInsensitiveContains(query) }
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
                        NavigationLink(restaurant.name) {
                            RestaurantDetailView(restaurant: restaurant)
                        }
                    }
                } footer: {
                    Text("Sample menus for now. These are not complete, verified restaurant menus.")
                }
            }
        }
        .navigationTitle("Restaurants")
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
    .modelContainer(for: [Restaurant.self, MenuItem.self, BuildableItemTemplate.self], inMemory: true)
}
