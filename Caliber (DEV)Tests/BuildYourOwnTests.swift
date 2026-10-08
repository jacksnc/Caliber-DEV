import Foundation
import Testing
@testable import Caliber__DEV_

@Suite("Build your own meal")
@MainActor
struct BuildYourOwnTests {
    private func fixture() -> (model: BuildYourOwnViewModel, base: BuildComponentCategory,
                               protein: BuildComponentCategory, toppings: BuildComponentCategory) {
        let base = BuildComponentCategory(name: "Entrée", selectionType: .single, isRequired: true, sortOrder: 0)
        base.options = [BuildComponentOption(name: "Burrito", calories: 290, protein: 8, carbs: 50, fat: 9)]
        let protein = BuildComponentCategory(name: "Protein", selectionType: .single, isRequired: false, sortOrder: 1)
        protein.options = [
            BuildComponentOption(name: "Chicken", calories: 180, protein: 32.5, carbs: 1, fat: 7, supportsDouble: true),
            BuildComponentOption(name: "Steak", calories: 150, protein: 21, carbs: 1, fat: 6, supportsDouble: true)
        ]
        let toppings = BuildComponentCategory(name: "Toppings", selectionType: .multiple, isRequired: false, sortOrder: 2)
        toppings.options = [
            BuildComponentOption(name: "Cheese", calories: 110, protein: 6, carbs: 1, fat: 9),
            BuildComponentOption(name: "Lettuce", calories: 5, protein: 0, carbs: 1, fat: 0)
        ]
        let template = BuildableItemTemplate(name: "Build Your Own Entrée")
        template.categories = [toppings, protein, base]
        return (BuildYourOwnViewModel(template: template), base, protein, toppings)
    }

    @Test("A required entrée is needed, while optional protein may be skipped")
    func requiredSelection() {
        let (model, base, _, _) = fixture()
        #expect(model.totals == MacroTotals())
        #expect(!model.canAdd)
        #expect(model.missingRequiredCategories.map(\.id) == [base.id])
        model.toggle(base.options[0], in: base)
        #expect(model.canAdd)
        #expect(model.missingRequiredCategories.isEmpty)
        #expect(!model.toggle(base.options[0], in: base))
        #expect(model.isSelected(base.options[0], in: base))
    }

    @Test("Totals sum selected ingredients and preserve fractional grams")
    func totalsSumSelections() {
        let (model, base, protein, toppings) = fixture()
        model.toggle(base.options[0], in: base)
        model.toggle(protein.options[0], in: protein)
        model.toggle(toppings.options[0], in: toppings)
        model.toggle(toppings.options[1], in: toppings)
        #expect(model.totals == MacroTotals(calories: 585, protein: 46.5, carbs: 53, fat: 25))
        #expect(model.selectedOptions.map(\.name) == ["Burrito", "Chicken", "Cheese", "Lettuce"])
    }

    @Test("Double scales only the chosen ingredient; Regular keeps it selected")
    func doubleThenRegular() {
        let (model, base, protein, _) = fixture()
        model.toggle(base.options[0], in: base)
        #expect(model.allowsDouble(for: protein.options[0], in: protein))
        model.toggleDouble(protein.options[0], in: protein)
        #expect(model.totals == MacroTotals(calories: 650, protein: 73, carbs: 52, fat: 23))
        model.toggleDouble(protein.options[0], in: protein)
        #expect(model.isSelected(protein.options[0], in: protein))
        #expect(model.totals == MacroTotals(calories: 470, protein: 40.5, carbs: 51, fat: 16))
    }

    @Test("Optional single choice can be removed, including its double portion")
    func optionalSelectionCanBeRemoved() {
        let (model, _, protein, _) = fixture()
        let chicken = protein.options[0]
        model.toggleDouble(chicken, in: protein)
        model.toggle(chicken, in: protein)
        #expect(!model.isSelected(chicken, in: protein))
        #expect(model.doubledOptionIDs.isEmpty)
        #expect(model.totals == MacroTotals())
        model.toggle(chicken, in: protein)
        #expect(model.multiplier(for: chicken) == 1)
    }

    @Test("Swiping a replacement protein clears the previous double portion")
    func swipeReplacementClearsPreviousDouble() {
        let (model, _, protein, _) = fixture()
        let chicken = protein.options[0]
        let steak = protein.options[1]
        model.toggleDouble(chicken, in: protein)
        model.toggleDouble(steak, in: protein)
        #expect(!model.isSelected(chicken, in: protein))
        #expect(model.doubledOptionIDs == [steak.id])
        #expect(model.totals == MacroTotals(calories: 300, protein: 42, carbs: 2, fat: 12))
        model.toggle(chicken, in: protein)
        #expect(model.doubledOptionIDs.isEmpty)
        #expect(model.totals == MacroTotals(calories: 180, protein: 32.5, carbs: 1, fat: 7))
    }

    @Test("Tapping a replacement protein clears the previous double portion")
    func tapReplacementClearsPreviousDouble() {
        let (model, _, protein, _) = fixture()
        model.toggleDouble(protein.options[0], in: protein)
        model.toggle(protein.options[1], in: protein)
        #expect(model.doubledOptionIDs.isEmpty)
        #expect(model.totals == MacroTotals(calories: 150, protein: 21, carbs: 1, fat: 6))
    }

    @Test("Removing one topping keeps the other selected topping")
    func multipleSelectionRemoval() {
        let (model, _, _, toppings) = fixture()
        model.toggle(toppings.options[0], in: toppings)
        model.toggle(toppings.options[1], in: toppings)
        #expect(model.totals == MacroTotals(calories: 115, protein: 6, carbs: 2, fat: 9))
        model.toggle(toppings.options[0], in: toppings)
        #expect(model.doubledOptionIDs.isEmpty)
        #expect(model.isSelected(toppings.options[1], in: toppings))
        #expect(model.totals == MacroTotals(calories: 5, protein: 0, carbs: 1, fat: 0))
    }

    @Test("Entrée format cannot be doubled like an ingredient")
    func entreeDoesNotDouble() {
        let (model, base, _, _) = fixture()
        model.toggle(base.options[0], in: base)
        #expect(!model.allowsDouble(for: base.options[0], in: base))
        model.toggleDouble(base.options[0], in: base)
        #expect(model.totals == MacroTotals(calories: 290, protein: 8, carbs: 50, fat: 9))
        #expect(model.doubledOptionIDs.isEmpty)
    }

    @Test("Unsupported options cannot be doubled or selected by the double action")
    func unsupportedOptionsDoNotDouble() {
        let (model, base, protein, toppings) = fixture()
        let unsupportedProtein = BuildComponentOption(name: "Another protein", calories: 100, protein: 10, carbs: 2, fat: 3)
        protein.options.append(unsupportedProtein)
        let rice = BuildComponentCategory(name: "Rice", selectionType: .single, isRequired: false, sortOrder: 3)
        rice.options = [BuildComponentOption(name: "White Rice", calories: 210, protein: 4, carbs: 40, fat: 4)]
        let beans = BuildComponentCategory(name: "Beans", selectionType: .single, isRequired: false, sortOrder: 4)
        beans.options = [BuildComponentOption(name: "Black Beans", calories: 130, protein: 8, carbs: 22, fat: 2)]
        model.template.categories.append(contentsOf: [rice, beans])
        for category in [base, toppings, rice, beans] {
            for option in category.options {
                #expect(!option.supportsDouble)
                #expect(!model.allowsDouble(for: option, in: category))
                model.toggleDouble(option, in: category)
                #expect(!model.isSelected(option, in: category))
            }
        }
        model.toggle(unsupportedProtein, in: protein)
        model.toggleDouble(unsupportedProtein, in: protein)
        #expect(model.isSelected(unsupportedProtein, in: protein))
        #expect(model.multiplier(for: unsupportedProtein) == 1)
        #expect(model.totals == MacroTotals(calories: 100, protein: 10, carbs: 2, fat: 3))
        #expect(model.doubledOptionIDs.isEmpty)
    }

    @Test("An eligible protein cannot be doubled through the wrong category")
    func doubleRequiresMatchingCategory() {
        let (model, _, protein, toppings) = fixture()
        let chicken = protein.options[0]
        #expect(!model.allowsDouble(for: chicken, in: toppings))
        model.toggleDouble(chicken, in: toppings)
        #expect(model.selections.isEmpty)
        #expect(model.doubledOptionIDs.isEmpty)
        #expect(model.totals == MacroTotals())

        let unrelatedCategory = BuildComponentCategory(name: "Protein", selectionType: .single, isRequired: false, sortOrder: 0)
        let unrelatedOption = BuildComponentOption(name: "Chicken", calories: 180, protein: 32, carbs: 1, fat: 7, supportsDouble: true)
        unrelatedCategory.options = [unrelatedOption]
        #expect(!model.allowsDouble(for: unrelatedOption, in: unrelatedCategory))
        model.toggleDouble(unrelatedOption, in: unrelatedCategory)
        #expect(model.selections.isEmpty)
        #expect(model.doubledOptionIDs.isEmpty)
    }
}
