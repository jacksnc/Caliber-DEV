//
//  Caliber__DEV_App.swift
//  Caliber (DEV)
//
//  Created by Jackson Crockett on 10/6/26.
//

import SwiftUI
import SwiftData

@main
struct Caliber__DEV_App: App {
    // UI checks use a temporary store so running tests cannot alter a user's diary.
    private var usesTemporaryTestStore: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--progress-ui-testing")
        #else
        false
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [
            FoodItem.self,
            Restaurant.self,
            MenuItem.self,
            MenuItemModifier.self,
            BuildableItemTemplate.self,
            BuildComponentCategory.self,
            BuildComponentOption.self,
            SavedMeal.self,
            SavedMealItem.self,
            DiaryEntry.self,
            WeightEntry.self,
            ProgressEntry.self,
            ProgressPhoto.self,
            Note.self,
            UserProfile.self
        ], inMemory: usesTemporaryTestStore)
    }
}
