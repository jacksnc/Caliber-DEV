//
//  MyFoodsView.swift
//  Caliber (DEV)
//

import SwiftUI
import SwiftData

/// The Food Library's "My Foods" folder: every standalone food the user has
/// chosen to save for reuse (see the "Save to My Foods" toggle in
/// AddFoodView). Tapping one logs it again without retyping its macros.
struct MyFoodsView: View {
    @Environment(\.locale) private var locale
    @Query(filter: #Predicate<FoodItem> { $0.isSavedToLibrary }, sort: \FoodItem.name)
    private var savedFoods: [FoodItem]

    var body: some View {
        Group {
            if savedFoods.isEmpty {
                ContentUnavailableView(
                    "No Saved Foods Yet",
                    systemImage: "carrot",
                    description: Text("Foods you save while adding them in the Diary's \"Add Food\" screen will show up here.")
                )
            } else {
                List(savedFoods) { food in
                    NavigationLink {
                        SavedFoodDetailView(food: food)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(food.name)
                            Text("\(NutritionInput.format(food.calories, locale: locale)) cal · \(NutritionInput.format(food.proteinGrams, locale: locale))p \(NutritionInput.format(food.carbGrams, locale: locale))c \(NutritionInput.format(food.fatGrams, locale: locale))f")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("My Foods")
    }
}

#Preview {
    NavigationStack {
        MyFoodsView()
    }
    .modelContainer(for: [FoodItem.self, DiaryEntry.self], inMemory: true)
}
