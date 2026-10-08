//
//  RestaurantLibraryService.swift
//  Caliber (DEV)
//

import Foundation

/// Abstracts "fetch the restaurant library" so a real backend/database can
/// replace this later without touching any view code.
@MainActor
protocol RestaurantLibraryService {
    func fetchRestaurants() async throws -> [Restaurant]
}

/// Temporary in-memory implementation with a few sample restaurants until a
/// real restaurant database exists. Restaurants with a flat menu (Chick-fil-A,
/// Longhorn) have their items tagged with a MenuCategory for grouping.
/// Chipotle instead has a `buildableTemplates` flow that mirrors the
/// step-by-step mechanism of its real nutrition calculator — all the
/// component nutrition values here are placeholders until a real database
/// backs this screen.
struct MockRestaurantLibraryService: RestaurantLibraryService {
    func fetchRestaurants() async throws -> [Restaurant] {
        [chickFilA(), longhornSteakhouse(), chipotle()]
    }

    private func chickFilA() -> Restaurant {
        let restaurant = Restaurant(name: "Chick-fil-A")

        let sandwich = MenuItem(name: "Chicken Sandwich", baseCalories: 440, baseProtein: 28, baseCarbs: 41, baseFat: 19, category: .entree)
        sandwich.modifiers = [
            MenuItemModifier(name: "Add Cheese", calorieDelta: 50, proteinDelta: 3, carbDelta: 1, fatDelta: 4),
            MenuItemModifier(name: "No Bun", calorieDelta: -130, proteinDelta: -4, carbDelta: -24, fatDelta: -2)
        ]

        let waffleFries = MenuItem(name: "Waffle Fries (Medium)", baseCalories: 420, baseProtein: 5, baseCarbs: 45, baseFat: 24, category: .side)
        let lemonade = MenuItem(name: "Lemonade (Medium)", baseCalories: 220, baseProtein: 0, baseCarbs: 58, baseFat: 0, category: .drink)

        restaurant.menuItems = [sandwich, waffleFries, lemonade]
        return restaurant
    }

    private func longhornSteakhouse() -> Restaurant {
        let restaurant = Restaurant(name: "Longhorn Steakhouse")

        let filet = MenuItem(name: "6oz Flo's Filet", baseCalories: 300, baseProtein: 36, baseCarbs: 0, baseFat: 17, category: .entree)

        let potato = MenuItem(name: "Loaded Baked Potato", baseCalories: 530, baseProtein: 11, baseCarbs: 57, baseFat: 29, category: .side)
        potato.modifiers = [
            MenuItemModifier(name: "No Sour Cream", calorieDelta: -60, proteinDelta: -1, carbDelta: -2, fatDelta: -6)
        ]

        let dessert = MenuItem(name: "Chocolate Stampede", baseCalories: 1660, baseProtein: 20, baseCarbs: 180, baseFat: 97, category: .dessert)

        restaurant.menuItems = [filet, potato, dessert]
        return restaurant
    }

    /// Chipotle's entrée builder, modeled closely on the real nutrition
    /// calculator's flow: pick an entrée style, a protein, rice, beans,
    /// salsas, free toppings, and extra-cost add-ons (guac/queso) — in that
    /// order, with a running total. Eligible proteins can be doubled with a swipe
    /// in BuildYourOwnView, so there's no separate "double" catalog entry.
    /// Chips, sides, and drinks are separate flat menu items below the
    /// builder, same as a real restaurant's menu.
    private func chipotle() -> Restaurant {
        let restaurant = Restaurant(name: "Chipotle")
        let builder = BuildableItemTemplate(name: "Build Your Own Entrée")

        let base = BuildComponentCategory(name: "Entrée", selectionType: .single, isRequired: true, sortOrder: 0)
        base.options = [
            BuildComponentOption(name: "Burrito (Flour Tortilla)", calories: 290, protein: 8, carbs: 50, fat: 9),
            BuildComponentOption(name: "Bowl (No Tortilla)", calories: 0, protein: 0, carbs: 0, fat: 0),
            BuildComponentOption(name: "Salad (Extra Lettuce)", calories: 15, protein: 1, carbs: 3, fat: 0),
            BuildComponentOption(name: "Hard Shell Tacos (3)", calories: 240, protein: 6, carbs: 33, fat: 9),
            BuildComponentOption(name: "Soft Flour Tortilla Tacos (3)", calories: 210, protein: 6, carbs: 36, fat: 7),
            BuildComponentOption(name: "Soft Corn Tortilla Tacos (3)", calories: 150, protein: 4, carbs: 33, fat: 2)
        ]

        // No separate "(Double)" entries here — BuildYourOwnView lets the
        // user swipe an eligible protein to double it instead.
        let protein = BuildComponentCategory(name: "Protein", selectionType: .single, isRequired: false, sortOrder: 1)
        protein.options = [
            BuildComponentOption(name: "Chicken", calories: 180, protein: 32, carbs: 1, fat: 7, supportsDouble: true),
            BuildComponentOption(name: "Steak", calories: 150, protein: 21, carbs: 1, fat: 6, supportsDouble: true),
            BuildComponentOption(name: "Barbacoa", calories: 170, protein: 20, carbs: 2, fat: 9, supportsDouble: true),
            BuildComponentOption(name: "Carnitas", calories: 210, protein: 23, carbs: 0, fat: 12, supportsDouble: true),
            BuildComponentOption(name: "Sofritas", calories: 150, protein: 8, carbs: 9, fat: 10, supportsDouble: true)
        ]

        let rice = BuildComponentCategory(name: "Rice", selectionType: .single, isRequired: false, sortOrder: 2)
        rice.options = [
            BuildComponentOption(name: "White Rice", calories: 210, protein: 4, carbs: 40, fat: 4),
            BuildComponentOption(name: "Brown Rice", calories: 210, protein: 4, carbs: 36, fat: 6)
        ]

        let beans = BuildComponentCategory(name: "Beans", selectionType: .single, isRequired: false, sortOrder: 3)
        beans.options = [
            BuildComponentOption(name: "Black Beans", calories: 130, protein: 8, carbs: 22, fat: 2),
            BuildComponentOption(name: "Pinto Beans", calories: 130, protein: 8, carbs: 20, fat: 2)
        ]

        let salsa = BuildComponentCategory(name: "Salsa", selectionType: .multiple, isRequired: false, sortOrder: 4)
        salsa.options = [
            BuildComponentOption(name: "Fresh Tomato Salsa (Mild)", calories: 25, protein: 0, carbs: 4, fat: 0),
            BuildComponentOption(name: "Roasted Chili-Corn Salsa (Medium)", calories: 80, protein: 3, carbs: 16, fat: 1),
            BuildComponentOption(name: "Tomatillo Green-Chili Salsa (Medium)", calories: 15, protein: 1, carbs: 4, fat: 0),
            BuildComponentOption(name: "Tomatillo Red-Chili Salsa (Hot)", calories: 30, protein: 1, carbs: 4, fat: 0)
        ]

        let toppings = BuildComponentCategory(name: "Toppings", selectionType: .multiple, isRequired: false, sortOrder: 5)
        toppings.options = [
            BuildComponentOption(name: "Fajita Veggies", calories: 20, protein: 1, carbs: 4, fat: 0),
            BuildComponentOption(name: "Lettuce", calories: 5, protein: 0, carbs: 1, fat: 0),
            BuildComponentOption(name: "Cheese", calories: 110, protein: 6, carbs: 1, fat: 9),
            BuildComponentOption(name: "Sour Cream", calories: 110, protein: 2, carbs: 2, fat: 10)
        ]

        let quesoAndGuac = BuildComponentCategory(name: "Queso & Guac", selectionType: .multiple, isRequired: false, sortOrder: 6)
        quesoAndGuac.options = [
            BuildComponentOption(name: "Guacamole", calories: 230, protein: 2, carbs: 8, fat: 22),
            BuildComponentOption(name: "Queso Blanco", calories: 120, protein: 4, carbs: 4, fat: 9)
        ]

        builder.categories = [base, protein, rice, beans, salsa, toppings, quesoAndGuac]
        restaurant.buildableTemplates = [builder]

        let chips = MenuItem(name: "Chips", baseCalories: 570, baseProtein: 7, baseCarbs: 69, baseFat: 29, category: .side)
        let chipsGuac = MenuItem(name: "Chips & Guacamole", baseCalories: 770, baseProtein: 9, baseCarbs: 79, baseFat: 47, category: .side)
        let chipsQueso = MenuItem(name: "Chips & Queso Blanco", baseCalories: 730, baseProtein: 12, baseCarbs: 75, baseFat: 41, category: .side)
        let chipsSalsa = MenuItem(name: "Chips & Fresh Tomato Salsa", baseCalories: 600, baseProtein: 7, baseCarbs: 75, baseFat: 29, category: .side)

        let fountainDrink = MenuItem(name: "Fountain Drink (Large)", baseCalories: 220, baseProtein: 0, baseCarbs: 60, baseFat: 0, category: .drink)
        let izze = MenuItem(name: "Izze Sparkling Juice", baseCalories: 140, baseProtein: 0, baseCarbs: 35, baseFat: 0, category: .drink)
        let water = MenuItem(name: "Bottled Water", baseCalories: 0, baseProtein: 0, baseCarbs: 0, baseFat: 0, category: .drink)

        restaurant.menuItems = [chips, chipsGuac, chipsQueso, chipsSalsa, fountainDrink, izze, water]
        return restaurant
    }
}
