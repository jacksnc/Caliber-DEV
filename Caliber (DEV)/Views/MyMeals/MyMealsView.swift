//
//  MyMealsView.swift
//  Caliber (DEV)
//

import SwiftUI
import SwiftData

/// The Food Library's "My Meals" folder: saved combinations of foods that
/// can be logged together in one tap. Starts empty until a meal is saved —
/// there's no "create a meal" flow yet, so this just lists whatever exists.
struct MyMealsView: View {
    @Environment(\.locale) private var locale
    @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]

    var body: some View {
        Group {
            if savedMeals.isEmpty {
                ContentUnavailableView(
                    "No Saved Meals Yet",
                    systemImage: "square.stack.3d.up",
                    description: Text("Saved combinations of foods will show up here.")
                )
            } else {
                List(savedMeals) { meal in
                    NavigationLink {
                        SavedMealDetailView(meal: meal)
                    } label: {
                        let totals = MacroCalculator.totals(for: meal.items)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(meal.name)
                            Text("\(NutritionInput.format(totals.calories, locale: locale)) cal · \(meal.items.count) item\(meal.items.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("My Meals")
    }
}

#Preview {
    NavigationStack {
        MyMealsView()
    }
    .modelContainer(for: [SavedMeal.self, SavedMealItem.self, FoodItem.self, DiaryEntry.self], inMemory: true)
}
