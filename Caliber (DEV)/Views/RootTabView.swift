//
//  RootTabView.swift
//  Caliber (DEV)
//

import SwiftUI
import SwiftData

/// The app's main tab bar. Each tab's real screen lives in its own file;
/// tabs we haven't built yet show a simple placeholder.
struct RootTabView: View {
    var body: some View {
        TabView {
            DiaryView()
                .tabItem { Label("Diary", systemImage: "fork.knife") }

            FoodSearchView()
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }

            FoodLibraryView()
                .tabItem { Label("Food Library", systemImage: "books.vertical") }

            ProgressDashboardView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }

            ProfilePlaceholderView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [FoodItem.self, DiaryEntry.self, Restaurant.self, SavedMeal.self, ProgressEntry.self, WeightEntry.self, ProgressPhoto.self], inMemory: true)
}
