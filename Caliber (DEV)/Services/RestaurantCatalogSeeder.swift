import Foundation
import SwiftData

/// Both food search and restaurant browsing can open first. Check the store
/// again after fetching so those screens cannot insert the sample catalog twice.
@MainActor
enum RestaurantCatalogSeeder {
    static func seedIfNeeded(
        in context: ModelContext,
        using service: (any RestaurantLibraryService)? = nil
    ) async throws {
        let descriptor = FetchDescriptor<Restaurant>()
        let existing = try context.fetch(descriptor)
        if !existing.isEmpty {
            try updateChipotleBuilder(in: existing, context: context)
            return
        }

        let catalogService = service ?? MockRestaurantLibraryService()
        let restaurants = try await catalogService.fetchRestaurants()
        try Task.checkCancellation()
        // Another screen may have seeded the catalog while this fetch awaited.
        let rechecked = try context.fetch(descriptor)
        if !rechecked.isEmpty {
            try updateChipotleBuilder(in: rechecked, context: context)
            return
        }

        for restaurant in restaurants {
            context.insert(restaurant)
        }
        do {
            try context.save()
        } catch {
            // Remove only these new records; preserve unrelated diary edits.
            for restaurant in restaurants {
                context.delete(restaurant)
            }
            throw error
        }
    }

    /// Correct only Chipotle's builder rules in existing installs. Nutrition,
    /// menu items, other restaurants, and diary entries stay as the user has them.
    private static func updateChipotleBuilder(in restaurants: [Restaurant], context: ModelContext) throws {
        let categories = restaurants
            .filter { $0.name.caseInsensitiveCompare("Chipotle") == .orderedSame }
            .flatMap(\.buildableTemplates)
            .flatMap(\.categories)

        let requiredProteinCategories = categories.filter { $0.name == "Protein" && $0.isRequired }
        let eligibleProteins: Set<String> = ["Chicken", "Steak", "Barbacoa", "Carnitas", "Sofritas"]
        var changedOptions: [(option: BuildComponentOption, previousValue: Bool)] = []
        for category in categories {
            for option in category.options {
                let shouldSupportDouble = category.name == "Protein" && eligibleProteins.contains(option.name)
                if option.supportsDouble != shouldSupportDouble {
                    changedOptions.append((option, option.supportsDouble))
                    option.supportsDouble = shouldSupportDouble
                }
            }
        }
        guard !requiredProteinCategories.isEmpty || !changedOptions.isEmpty else { return }

        // A veggie entrée can skip protein, while the entrée format is required.
        requiredProteinCategories.forEach { $0.isRequired = false }
        do {
            try context.save()
        } catch {
            requiredProteinCategories.forEach { $0.isRequired = true }
            changedOptions.forEach { $0.option.supportsDouble = $0.previousValue }
            throw error
        }
    }
}
