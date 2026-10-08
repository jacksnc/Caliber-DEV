import Foundation
import Observation

/// Keeps ingredient selection and portion math separate from the screen so
/// these rules can be tested without opening the app or a database.
@Observable
final class BuildYourOwnViewModel {
    let template: BuildableItemTemplate
    private(set) var selections: [UUID: Set<UUID>] = [:]
    private(set) var doubledOptionIDs: Set<UUID> = []

    init(template: BuildableItemTemplate) {
        self.template = template
    }

    var orderedCategories: [BuildComponentCategory] {
        template.categories.sorted { $0.sortOrder < $1.sortOrder }
    }

    var selectedOptions: [BuildComponentOption] {
        orderedCategories.flatMap { category in
            category.options.filter { isSelected($0, in: category) }
        }
    }

    var missingRequiredCategories: [BuildComponentCategory] {
        orderedCategories.filter { category in
            category.isRequired && (selections[category.id]?.isEmpty ?? true)
        }
    }

    var canAdd: Bool {
        missingRequiredCategories.isEmpty && !selectedOptions.isEmpty
    }

    /// Nutrition for one assembled item. Diary quantity is applied separately.
    var totals: MacroTotals {
        selectedOptions.reduce(into: MacroTotals()) { total, option in
            let portion = multiplier(for: option)
            total.calories += option.calories * portion
            total.protein += option.protein * portion
            total.carbs += option.carbs * portion
            total.fat += option.fat * portion
        }
    }

    func isSelected(_ option: BuildComponentOption, in category: BuildComponentCategory) -> Bool {
        selections[category.id]?.contains(option.id) ?? false
    }

    func multiplier(for option: BuildComponentOption) -> Double {
        option.supportsDouble && doubledOptionIDs.contains(option.id) ? 2 : 1
    }

    func allowsDouble(for option: BuildComponentOption, in category: BuildComponentCategory) -> Bool {
        // The catalog decides which proteins have this portion choice. A
        // category name alone must not enable doubling rice, beans, or toppings.
        option.supportsDouble
            && template.categories.contains { $0.id == category.id }
            && category.options.contains { $0.id == option.id }
    }

    @discardableResult
    func toggle(_ option: BuildComponentOption, in category: BuildComponentCategory) -> Bool {
        if isSelected(option, in: category) {
            // Required single-choice groups always retain one selection.
            if category.selectionType == .single && category.isRequired { return false }
            selections[category.id]?.remove(option.id)
            doubledOptionIDs.remove(option.id)
        } else {
            select(option, in: category)
        }
        return true
    }

    /// A double action also selects the ingredient. Returning to regular
    /// keeps it selected; tapping the row removes optional ingredients.
    func toggleDouble(_ option: BuildComponentOption, in category: BuildComponentCategory) {
        guard allowsDouble(for: option, in: category) else { return }
        let wasDoubled = doubledOptionIDs.contains(option.id)
        select(option, in: category)
        if wasDoubled {
            doubledOptionIDs.remove(option.id)
        } else {
            doubledOptionIDs.insert(option.id)
        }
    }

    private func select(_ option: BuildComponentOption, in category: BuildComponentCategory) {
        switch category.selectionType {
        case .single:
            // Clear the old ingredient's double state on either tap or swipe.
            // Switching back to it later starts with a regular portion.
            let replacedIDs = (selections[category.id] ?? []).subtracting([option.id])
            doubledOptionIDs.subtract(replacedIDs)
            selections[category.id] = [option.id]
        case .multiple:
            selections[category.id, default: []].insert(option.id)
        }
    }
}
