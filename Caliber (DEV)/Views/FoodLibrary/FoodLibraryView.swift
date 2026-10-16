//
//  FoodLibraryView.swift
//  Caliber (DEV)
//

import SwiftData
import SwiftUI

/// The "Food Library" tab: a browsable catalog of food sources, organized
/// into subgenres — restaurants, plus the user's own saved meals and foods.
struct FoodLibraryView: View {
  @State private var databaseSummary = "Opening the offline food database…"
  var body: some View {
    NavigationStack {
      List {
        Section {
          NavigationLink {
            FoodSearchView()
          } label: {
            Label("Search Foods", systemImage: "magnifyingglass").frame(minHeight: 48)
          }.accessibilityIdentifier("openFoodSearch")
          NavigationLink {
            BarcodeFoodLookupView()
          } label: {
            Label("Scan a Barcode", systemImage: "barcode.viewfinder").frame(minHeight: 48)
          }.accessibilityIdentifier("openBarcode")

          NavigationLink {
            RestaurantListView()
          } label: {
            Label("Restaurants", systemImage: "building.2")
          }

          NavigationLink {
            MyMealsView()
          } label: {
            Label("My Meals", systemImage: "square.stack.3d.up")
          }

          NavigationLink {
            MyFoodsView()
          } label: {
            Label("My Foods", systemImage: "carrot")
          }
        } header: {
          Text("Browse")
        } footer: {
          Text(
            databaseSummary
              + " Restaurant menus currently contain sample values and your custom items."
          )
        }
      }
      .navigationTitle("Food Library")
      .task {
        let catalog = await BundledFoodSearchService.prepared()
        if let count = try? catalog.foodCount {
          databaseSummary =
            "\(count.formatted()) foods are available offline, with source years and known portion weights."
        } else {
          databaseSummary =
            "The offline food database is unavailable. You can still enter food manually."
        }
      }
    }
  }
}

#Preview {
  FoodLibraryView()
    .modelContainer(for: [Restaurant.self, SavedMeal.self, FoodItem.self], inMemory: true)
    .environmentObject(
      FoodLibraryPreferences(defaults: UserDefaults(suiteName: "Caliber.Food.Previews")!))
}
