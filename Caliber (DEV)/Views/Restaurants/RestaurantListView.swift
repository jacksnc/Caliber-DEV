import CaliberDatabase
import HeliosDesign
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
  @Environment(\.heliosTheme) private var theme
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
      Group {
        // Look book: one glass search field above the list.
        HStack(spacing: HeliosTokens.space(2)) {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(theme.palette.text.secondary.color)
            .accessibilityHidden(true)
          TextField("Search restaurants", text: $searchText, axis: .vertical)
            .heliosFont(.body)
            .accessibilityLabel("Search restaurants")
            .accessibilityIdentifier("restaurantSearch")
        }
        .padding(.horizontal, HeliosTokens.space(4))
        .frame(minHeight: 52)
        .background { GlassBackground(level: .raised, cornerRadius: 16) }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
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
                if let source = importedCatalog.sources.first(where: {
                  $0.id == restaurant.sourceID
                }) {
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
                HStack(spacing: HeliosTokens.space(3)) {
                  Image(systemName: "fork.knife")
                    .foregroundStyle(theme.palette.accent.base.color)
                    .frame(width: 40, height: 40)
                    .background(
                      RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.palette.accent.subtle.color)
                    )
                    .accessibilityHidden(true)
                  VStack(alignment: .leading, spacing: 3) {
                    Text(restaurant.name).heliosFont(.bodyStrong)
                    Text(
                      "\(restaurant.menuItems.count) items · \(restaurant.buildableTemplates.count) builders"
                    )
                    .heliosFont(.caption)
                    .foregroundStyle(theme.palette.text.secondary.color)
                  }
                }
                .frame(minHeight: 48)
              }
              .accessibilityLabel(restaurant.name)
              .accessibilityValue(
                "\(restaurant.menuItems.count) menu items and \(restaurant.buildableTemplates.count) builders"
              )
            }
          } footer: {
            Text("Sample menus for now. These are not complete, verified restaurant menus.").font(
              .footnote
            ).fixedSize(horizontal: false, vertical: true)
          }
        }
      }
      .listRowBackground(CaliberRowBackground())
    }
    .caliberScreen()
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
