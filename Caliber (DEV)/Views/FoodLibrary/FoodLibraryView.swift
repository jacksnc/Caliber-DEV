//
//  FoodLibraryView.swift
//  Caliber (DEV)
//

import SwiftUI
import SwiftData

/// The "Food Library" tab: a browsable catalog of food sources, organized
/// into subgenres — restaurants, plus the user's own saved meals and foods.
struct FoodLibraryView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Browse") {
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
                }
            }
            .navigationTitle("Food Library")
        }
    }
}

#Preview {
    FoodLibraryView()
        .modelContainer(for: [Restaurant.self, SavedMeal.self, FoodItem.self], inMemory: true)
}
