import Foundation
import SwiftData
import Testing
@testable import Caliber__DEV_

@MainActor
@Suite("Restaurant catalog seeding")
struct RestaurantCatalogSeederTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Restaurant.self, MenuItem.self, MenuItemModifier.self,
            BuildableItemTemplate.self, BuildComponentCategory.self,
            BuildComponentOption.self, FoodItem.self, DiaryEntry.self,
            SavedMeal.self, SavedMealItem.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    private func makeMenuItem() -> MenuItem {
        MenuItem(
            name: "My existing side", baseCalories: 123, baseProtein: 4,
            baseCarbs: 20, baseFat: 3, category: .side
        )
    }

    @Test("Repeated loading stores the catalog only once and persists its items")
    func repeatedLoadingSeedsOnce() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let restaurant = Restaurant(name: "Sample Restaurant")
        let menuItem = makeMenuItem()
        restaurant.menuItems = [menuItem]
        let service = TestRestaurantService(restaurants: [restaurant])

        try await RestaurantCatalogSeeder.seedIfNeeded(in: context, using: service)
        try await RestaurantCatalogSeeder.seedIfNeeded(in: context, using: service)
        try await RestaurantCatalogSeeder.seedIfNeeded(in: context, using: service)

        #expect(service.fetchCount == 1)
        // A fresh context proves the seeder saved, rather than only inserting.
        let reloadedContext = ModelContext(container)
        let restaurants = try reloadedContext.fetch(FetchDescriptor<Restaurant>())
        let items = try reloadedContext.fetch(FetchDescriptor<MenuItem>())
        #expect(restaurants.count == 1)
        #expect(restaurants.first?.id == restaurant.id)
        #expect(restaurants.first?.menuItems.count == 1)
        #expect(items.count == 1)
        #expect(items.first?.id == menuItem.id)
        #expect(items.first?.restaurant?.id == restaurant.id)
    }

    @Test("Existing catalog and diary data survive the targeted veggie correction")
    func existingDataIsPreserved() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let chipotle = Restaurant(name: "Chipotle")
        let builder = BuildableItemTemplate(name: "My existing builder")
        let entree = BuildComponentCategory(name: "Entrée", selectionType: .single, isRequired: true, sortOrder: 0)
        let protein = BuildComponentCategory(name: "Protein", selectionType: .single, isRequired: true, sortOrder: 1)
        let option = BuildComponentOption(name: "Existing protein", calories: 234, protein: 30, carbs: 2, fat: 10)
        protein.options = [option]
        builder.categories = [entree, protein]
        chipotle.buildableTemplates = [builder]
        let menuItem = makeMenuItem()
        chipotle.menuItems = [menuItem]

        let otherRestaurant = Restaurant(name: "My Restaurant")
        let otherBuilder = BuildableItemTemplate(name: "Other builder")
        let otherProtein = BuildComponentCategory(name: "Protein", selectionType: .single, isRequired: true, sortOrder: 0)
        otherBuilder.categories = [otherProtein]
        otherRestaurant.buildableTemplates = [otherBuilder]

        let food = FoodItem(
            name: "My saved food", calories: 100, proteinGrams: 5,
            carbGrams: 15, fatGrams: 2, servingDescription: "1 bowl",
            isSavedToLibrary: true
        )
        let originalDate = Date(timeIntervalSince1970: 1_700_000_000)
        let diaryEntry = DiaryEntry(
            date: originalDate, mealType: .dinner, foodItem: food,
            quantity: 1.5, note: "Keep this note"
        )
        context.insert(chipotle)
        context.insert(otherRestaurant)
        context.insert(food)
        context.insert(diaryEntry)
        try context.save()
        let service = TestRestaurantService(restaurants: [Restaurant(name: "Replacement")])

        try await RestaurantCatalogSeeder.seedIfNeeded(in: context, using: service)
        try await RestaurantCatalogSeeder.seedIfNeeded(in: context, using: service)

        #expect(service.fetchCount == 0)
        let reloadedContext = ModelContext(container)
        let restaurants = try reloadedContext.fetch(FetchDescriptor<Restaurant>())
        #expect(Set(restaurants.map(\.id)) == Set([chipotle.id, otherRestaurant.id]))
        let categories = try reloadedContext.fetch(FetchDescriptor<BuildComponentCategory>())
        #expect(categories.count == 3)
        #expect(categories.first { $0.id == protein.id }?.isRequired == false)
        #expect(categories.first { $0.id == entree.id }?.isRequired == true)
        #expect(categories.first { $0.id == otherProtein.id }?.isRequired == true)
        let preservedProtein = try #require(categories.first { $0.id == protein.id })
        #expect(preservedProtein.options.count == 1)
        #expect(preservedProtein.options.first?.id == option.id)
        #expect(preservedProtein.options.first?.calories == 234)
        #expect(preservedProtein.options.first?.supportsDouble == false)

        let items = try reloadedContext.fetch(FetchDescriptor<MenuItem>())
        #expect(items.count == 1)
        #expect(items.first?.id == menuItem.id)
        #expect(items.first?.name == "My existing side")
        #expect(items.first?.baseCalories == 123)
        #expect(items.first?.category == .side)
        let entries = try reloadedContext.fetch(FetchDescriptor<DiaryEntry>())
        let preservedEntry = try #require(entries.first)
        #expect(entries.count == 1)
        #expect(preservedEntry.id == diaryEntry.id)
        #expect(preservedEntry.date == originalDate)
        #expect(preservedEntry.mealType == .dinner)
        #expect(preservedEntry.quantity == 1.5)
        #expect(preservedEntry.calories == 150)
        #expect(preservedEntry.note == "Keep this note")
        #expect(preservedEntry.foodItem?.id == food.id)
        #expect(preservedEntry.foodItem?.name == "My saved food")
        #expect(preservedEntry.foodItem?.isSavedToLibrary == true)
    }

    @Test("Fresh Chipotle catalog enables double portions only for its eligible proteins")
    func freshCatalogDoubleEligibility() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        try await RestaurantCatalogSeeder.seedIfNeeded(in: context)

        let reloadedContext = ModelContext(container)
        let restaurants = try reloadedContext.fetch(FetchDescriptor<Restaurant>())
        let chipotle = try #require(restaurants.first { $0.name == "Chipotle" })
        let categories = chipotle.buildableTemplates.flatMap(\.categories)
        let eligibleProteins: Set<String> = ["Chicken", "Steak", "Barbacoa", "Carnitas", "Sofritas"]
        var enabledNames: Set<String> = []
        for category in categories {
            for option in category.options {
                let expected = category.name == "Protein" && eligibleProteins.contains(option.name)
                #expect(option.supportsDouble == expected)
                if option.supportsDouble { enabledNames.insert(option.name) }
            }
        }
        #expect(enabledNames == eligibleProteins)
    }

    @Test("Existing Chipotle portions are corrected and saved without replacing custom nutrition")
    func existingPortionEligibilityIsCorrected() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let chipotle = Restaurant(name: "Chipotle")
        let builder = BuildableItemTemplate(name: "Existing builder")
        // Protein is already optional, so changing portion flags must itself
        // trigger a save even when the earlier veggie correction is unnecessary.
        let protein = BuildComponentCategory(name: "Protein", selectionType: .single, isRequired: false, sortOrder: 1)
        let names = ["Chicken", "Steak", "Barbacoa", "Carnitas", "Sofritas"]
        let knownProteins = names.map { name in
            BuildComponentOption(name: name, calories: 234, protein: 30.5, carbs: 2, fat: 10)
        }
        let unknownProtein = BuildComponentOption(name: "Custom protein", calories: 321, protein: 20, carbs: 4, fat: 12, supportsDouble: true)
        protein.options = knownProteins + [unknownProtein]
        let rice = BuildComponentCategory(name: "Rice", selectionType: .single, isRequired: false, sortOrder: 2)
        let riceOption = BuildComponentOption(name: "White Rice", calories: 205, protein: 4, carbs: 39, fat: 3, supportsDouble: true)
        rice.options = [riceOption]
        let toppings = BuildComponentCategory(name: "Toppings", selectionType: .multiple, isRequired: false, sortOrder: 3)
        // A matching name outside Protein must not acquire the capability.
        let misplacedChicken = BuildComponentOption(name: "Chicken", calories: 80, protein: 15, carbs: 0, fat: 2, supportsDouble: true)
        toppings.options = [misplacedChicken]
        builder.categories = [protein, rice, toppings]
        chipotle.buildableTemplates = [builder]

        let customRestaurant = Restaurant(name: "Custom Restaurant")
        let customBuilder = BuildableItemTemplate(name: "Custom builder")
        let customCategory = BuildComponentCategory(name: "Protein", selectionType: .single, isRequired: true, sortOrder: 0)
        let customOption = BuildComponentOption(name: "Chicken", calories: 777, protein: 60, carbs: 2, fat: 30, supportsDouble: true)
        customCategory.options = [customOption]
        customBuilder.categories = [customCategory]
        customRestaurant.buildableTemplates = [customBuilder]
        context.insert(chipotle)
        context.insert(customRestaurant)
        try context.save()

        let service = TestRestaurantService(restaurants: [])
        try await RestaurantCatalogSeeder.seedIfNeeded(in: context, using: service)
        try await RestaurantCatalogSeeder.seedIfNeeded(in: context, using: service)
        #expect(service.fetchCount == 0)
        let reloadedContext = ModelContext(container)
        let options = try reloadedContext.fetch(FetchDescriptor<BuildComponentOption>())
        #expect(options.count == 9)
        for original in knownProteins {
            let saved = try #require(options.first { $0.id == original.id })
            #expect(saved.supportsDouble)
            #expect(saved.name == original.name)
            #expect(saved.calories == 234)
            #expect(saved.protein == 30.5)
            #expect(saved.carbs == 2)
            #expect(saved.fat == 10)
        }
        for original in [unknownProtein, riceOption, misplacedChicken] {
            let saved = try #require(options.first { $0.id == original.id })
            #expect(!saved.supportsDouble)
            #expect(saved.name == original.name)
            #expect(saved.calories == original.calories)
        }
        let savedCustom = try #require(options.first { $0.id == customOption.id })
        #expect(savedCustom.supportsDouble)
        #expect(savedCustom.calories == 777)
        #expect(savedCustom.category?.isRequired == true)
    }

    @Test("A canceled fetch cannot insert a returned catalog")
    func canceledLoadDoesNotInsert() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let restaurant = Restaurant(name: "Should not be inserted")
        restaurant.menuItems = [makeMenuItem()]
        let service = TestRestaurantService(restaurants: [restaurant], cancelsLoad: true)

        // The stub cancels this child task but still returns results, like a
        // service that does not itself honor cancellation after its fetch.
        let load = Task { @MainActor in
            try await RestaurantCatalogSeeder.seedIfNeeded(in: context, using: service)
        }
        await #expect(throws: CancellationError.self) {
            try await load.value
        }

        #expect(service.fetchCount == 1)
        #expect(try context.fetch(FetchDescriptor<Restaurant>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<MenuItem>()).isEmpty)
        #expect(!context.hasChanges)
        let reloadedContext = ModelContext(container)
        #expect(try reloadedContext.fetch(FetchDescriptor<Restaurant>()).isEmpty)
    }
}

@MainActor
private final class TestRestaurantService: RestaurantLibraryService {
    let restaurants: [Restaurant]
    let cancelsLoad: Bool
    private(set) var fetchCount = 0

    init(restaurants: [Restaurant], cancelsLoad: Bool = false) {
        self.restaurants = restaurants
        self.cancelsLoad = cancelsLoad
    }

    func fetchRestaurants() async throws -> [Restaurant] {
        fetchCount += 1
        if cancelsLoad {
            withUnsafeCurrentTask { $0?.cancel() }
        }
        return restaurants
    }
}
