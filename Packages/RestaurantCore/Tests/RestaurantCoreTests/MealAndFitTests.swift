import XCTest
import FoodCore
@testable import RestaurantCore

final class MealBuilderTests: XCTestCase {
    private let library = Fixtures.library()
    private var barn: Restaurant { library.restaurant(id: "burger-barn")! }
    private var tacos: Restaurant { library.restaurant(id: "taco-tangent")! }
    private var cafe: Restaurant { library.restaurant(id: "bean-there-coffee")! }

    private let toppings = "burger-barn/burger-toppings"
    private let sauce = "burger-barn/burger-sauce"

    func testListedBuildIsUnchanged() {
        let result = MealBuilder.nutrients(for: OrderLine(itemID: "burger-barn/classic-barn-burger"), in: barn)
        XCTAssertEqual(result.nutrients.calories, 540)
        XCTAssertEqual(result.warnings, [])
        // Spelling out the defaults changes nothing.
        let burger = barn.item(id: "burger-barn/classic-barn-burger")!
        let explicit = OrderLine(itemID: burger.id, selections: MealBuilder.defaultSelections(for: burger, in: barn))
        XCTAssertEqual(MealBuilder.nutrients(for: explicit, in: barn).nutrients, result.nutrients)
    }

    func testRemovingDefaultOptionsSubtractsThem() {
        let noCheese = OrderLine(itemID: "burger-barn/classic-barn-burger", selections: [toppings: ["burger-barn/burger-toppings/lettuce-and-tomato"]])
        let a = MealBuilder.nutrients(for: noCheese, in: barn).nutrients
        XCTAssertEqual(a.calories, 460)
        XCTAssertEqual(a.proteinG, 23)
        XCTAssertEqual(a.carbsG, 39)
        XCTAssertEqual(a.fatG, 23)
        XCTAssertEqual(a[.sodium], 750)

        // Also drop the sauce (single, optional): 540 - 80 - 110 = 350.
        let plain = OrderLine(itemID: "burger-barn/classic-barn-burger", selections: [
            toppings: ["burger-barn/burger-toppings/lettuce-and-tomato"], sauce: [],
        ])
        let b = MealBuilder.nutrients(for: plain, in: barn).nutrients
        XCTAssertEqual(b.calories, 350)
        XCTAssertEqual(b.carbsG, 37)
        XCTAssertEqual(b.fatG, 11)
        XCTAssertEqual(b[.sodium], 570)
    }

    func testAddingExtrasAddsThem() {
        let withBacon = OrderLine(itemID: "burger-barn/classic-barn-burger", selections: [
            toppings: ["burger-barn/burger-toppings/cheese", "burger-barn/burger-toppings/lettuce-and-tomato", "burger-barn/burger-toppings/bacon"],
        ])
        let result = MealBuilder.nutrients(for: withBacon, in: barn)
        XCTAssertEqual(result.nutrients.calories, 610)
        XCTAssertEqual(result.nutrients.proteinG, 33)
        XCTAssertEqual(result.nutrients[.sodium], 1310)
        XCTAssertEqual(result.warnings, [])
    }

    func testSwappingInASingleChoiceGroup() {
        // Bowl: chicken (160 kcal) is the default; steak is 190.
        let steak = OrderLine(itemID: "taco-tangent/burrito-bowl", selections: ["taco-tangent/bowl-protein": ["taco-tangent/bowl-protein/steak"]])
        let result = MealBuilder.nutrients(for: steak, in: tacos).nutrients
        XCTAssertEqual(result.calories, 680)
        XCTAssertEqual(result.proteinG, 34)
        XCTAssertEqual(result.fatG, 27)
        XCTAssertEqual(result[.sodium], 1400)

        // Oat milk instead of 2% in a tall latte.
        let oat = OrderLine(itemID: "bean-there-coffee/latte", variantID: "tall", selections: ["bean-there-coffee/milk": ["bean-there-coffee/milk/oat-milk"]])
        let latte = MealBuilder.nutrients(for: oat, in: cafe).nutrients
        XCTAssertEqual(latte.calories, 160)
        XCTAssertEqual(latte.proteinG, 6)
        XCTAssertEqual(latte.carbsG, 17)
        XCTAssertEqual(latte.fatG, 7)
        XCTAssertEqual(latte[.sodium], 135)
    }

    func testSizesAndQuantities() {
        XCTAssertEqual(MealBuilder.nutrients(for: OrderLine(itemID: "burger-barn/fries", variantID: "large"), in: barn).nutrients.calories, 450)
        XCTAssertEqual(MealBuilder.nutrients(for: OrderLine(itemID: "burger-barn/fries", variantID: "large", quantity: 2), in: barn).nutrients.calories, 900)
        XCTAssertEqual(MealBuilder.nutrients(for: OrderLine(itemID: "burger-barn/fries", variantID: "small", quantity: 0.5), in: barn).nutrients.calories, 115)
    }

    func testScaledVariant() {
        var restaurant = barn
        let index = restaurant.items.firstIndex { $0.id == "burger-barn/side-salad" }!
        restaurant.items[index].variants = [ItemVariant(id: "half", name: "Half", scale: 0.5)]
        XCTAssertEqual(MealBuilder.nutrients(for: OrderLine(itemID: "burger-barn/side-salad", variantID: "half"), in: restaurant).nutrients.calories, 35)
    }

    func testWarnings() {
        XCTAssertEqual(MealBuilder.nutrients(for: OrderLine(itemID: "nope"), in: barn).warnings, [.unknownItem("nope")])
        XCTAssertEqual(MealBuilder.nutrients(for: OrderLine(itemID: "burger-barn/fries", variantID: "jumbo"), in: barn).warnings,
                       [.unknownVariant(item: "burger-barn/fries", variant: "jumbo")])
        XCTAssertEqual(MealBuilder.nutrients(for: OrderLine(itemID: "burger-barn/fries", selections: ["x": []]), in: barn).warnings,
                       [.unknownGroup(item: "burger-barn/fries", group: "x")])
        XCTAssertEqual(MealBuilder.nutrients(for: OrderLine(itemID: "burger-barn/classic-barn-burger", selections: [toppings: ["ghost"]]), in: barn).warnings,
                       [.unknownOption(group: toppings, option: "ghost")])

        let protein = "taco-tangent/bowl-protein"
        let both = OrderLine(itemID: "taco-tangent/burrito-bowl", selections: [protein: [protein + "/chicken", protein + "/steak"]])
        XCTAssertEqual(MealBuilder.nutrients(for: both, in: tacos).warnings, [.ruleViolated(group: protein)], "single choice")
        let none = OrderLine(itemID: "taco-tangent/burrito-bowl", selections: [protein: []])
        XCTAssertEqual(MealBuilder.nutrients(for: none, in: tacos).warnings, [.ruleViolated(group: protein)], "required group left empty")
    }

    func testMultipleGroupCap() {
        var restaurant = barn
        let index = restaurant.modifierGroups.firstIndex { $0.id == toppings }!
        restaurant.modifierGroups[index].rule = .multiple(max: 2)
        let three = OrderLine(itemID: "burger-barn/classic-barn-burger", selections: [
            toppings: ["burger-barn/burger-toppings/cheese", "burger-barn/burger-toppings/bacon", "burger-barn/burger-toppings/fried-egg"],
        ])
        XCTAssertEqual(MealBuilder.nutrients(for: three, in: restaurant).warnings, [.ruleViolated(group: toppings)])
    }

    func testNegativeResultsAreClamped() {
        var restaurant = barn
        restaurant.items.append(MenuItem(id: "burger-barn/tiny", name: "Tiny", section: "Sides", nutrients: NutrientSet([.energyKcal: 20, .protein: 1, .carbohydrate: 2, .fat: 0]),
                                         modifierGroupIDs: [toppings]))
        // Removing cheese (80 kcal) from a 20 kcal item would go negative.
        let line = OrderLine(itemID: "burger-barn/tiny", selections: [toppings: []])
        let result = MealBuilder.nutrients(for: line, in: restaurant)
        XCTAssertEqual(result.nutrients.calories, 0)
        XCTAssertTrue(result.warnings.contains(.clampedNegative(.energyKcal)))
    }

    func testMealTotalsAndIncompleteNutrients() {
        var restaurant = barn
        restaurant.items.append(MenuItem(id: "burger-barn/mystery", name: "Mystery", section: "Sides", nutrients: NutrientSet([.energyKcal: 100, .protein: 5, .carbohydrate: 10, .fat: 3])))
        let meal = MealBuilder.build([
            OrderLine(itemID: "burger-barn/classic-barn-burger"),
            OrderLine(itemID: "burger-barn/fries", variantID: "medium"),
            OrderLine(itemID: "burger-barn/mystery"),
            OrderLine(itemID: "missing"),
        ], in: restaurant)
        XCTAssertEqual(meal.totals.calories, 540 + 340 + 100)
        XCTAssertEqual(meal.totals.proteinG, 28 + 4 + 5)
        XCTAssertEqual(meal.totals[.sodium], 1050 + 230, "sum of the lines that report sodium")
        XCTAssertTrue(meal.incomplete.contains(.sodium), "the mystery item does not report sodium, so the total is a lower bound")
        XCTAssertFalse(meal.incomplete.contains(.energyKcal))
        XCTAssertEqual(meal.warnings, [.unknownItem("missing")])
        XCTAssertEqual(meal.lines.count, 4)
    }

    func testEmptyMeal() {
        let meal = MealBuilder.build([], in: barn)
        XCTAssertTrue(meal.totals.isEmpty)
        XCTAssertTrue(meal.incomplete.isEmpty)
    }
}

final class MacroFitTests: XCTestCase {
    private let library = Fixtures.library()
    private var barn: Restaurant { library.restaurant(id: "burger-barn")! }

    private func tiny() -> Restaurant {
        func item(_ id: String, _ kcal: Double, _ p: Double, _ c: Double, _ f: Double, section: String = "Main") -> MenuItem {
            MenuItem(id: "t/\(id)", name: id.uppercased(), section: section, nutrients: NutrientSet([.energyKcal: kcal, .protein: p, .carbohydrate: c, .fat: f]))
        }
        return Restaurant(
            id: "t", name: "Tiny", provenance: Provenance(kind: .demoFictional, sourceName: "test", license: .cc0, asOf: "2026-10"),
            items: [item("a", 500, 40, 40, 20), item("b", 300, 10, 40, 10), item("c", 200, 25, 5, 8, section: "Side")]
        )
    }

    func testObviousBestMealComesFirst() {
        let goal = MacroGoal(calories: 480...520, proteinMin: 40)
        let result = MacroFitFinder.find(in: tiny(), goal: goal, structure: .anyCombination(maxItems: 2))
        let top = result.suggestions[0]
        XCTAssertEqual(top.lines.map(\.itemID), ["t/a"])
        XCTAssertTrue(top.meetsGoal)
        // B + C reaches 500 kcal but only 35 g protein: close, not meeting the goal.
        let bc = result.suggestions.first { Set($0.lines.map(\.itemID)) == ["t/b", "t/c"] }
        XCTAssertNotNil(bc)
        XCTAssertFalse(bc!.meetsGoal)
        XCTAssertGreaterThan(bc!.penalty, top.penalty)
        XCTAssertEqual(result.itemsConsidered, 3)
        XCTAssertFalse(result.truncated)
    }

    func testRepeatsBecomeQuantities() {
        let result = MacroFitFinder.find(in: tiny(), goal: MacroGoal(calories: 380...420, proteinMin: 45), structure: .anyCombination(maxItems: 3))
        // Two C (200 kcal, 25 g) = 400 kcal, 50 g protein.
        let doubled = result.suggestions.first { $0.lines.count == 1 && $0.lines[0].itemID == "t/c" && $0.lines[0].quantity == 2 }
        XCTAssertNotNil(doubled)
        XCTAssertTrue(doubled!.meetsGoal)
        XCTAssertEqual(doubled!.totals.calories, 400)
    }

    func testResultsAreSortedAndUnique() {
        let result = MacroFitFinder.find(in: barn, goal: .fitting(remainingCalories: 650, proteinMin: 30), limit: 8)
        XCTAssertEqual(result.suggestions.count, 8)
        XCTAssertEqual(result.suggestions.map(\.penalty), result.suggestions.map(\.penalty).sorted())
        let signatures = result.suggestions.map { $0.lines.map { "\($0.itemID)#\($0.variantID ?? "")x\($0.quantity)" }.sorted() }
        XCTAssertEqual(Set(signatures.map { $0.joined() }).count, signatures.count)
        XCTAssertTrue(result.suggestions[0].meetsGoal, "plenty of Burger Barn orders land in 585-715 kcal with 30 g protein")
        for suggestion in result.suggestions {
            // Totals reported with each suggestion are exactly what the meal builder says.
            XCTAssertEqual(MealBuilder.build(suggestion.lines, in: barn).totals, suggestion.totals)
        }
    }

    func testMatchesBruteForce() {
        // Independent enumeration of every order of up to two items against the same penalty function.
        let goal = MacroGoal.fitting(remainingCalories: 700, proteinMin: 35, carbsMax: 90)
        var entries: [(NutrientSet, Int)] = []
        var singles: [NutrientSet] = []
        for item in barn.items {
            if item.variants.isEmpty { singles.append(item.nutrients) } else { for v in item.variants { singles.append(item.baseNutrients(variantID: v.id)) } }
        }
        func sum(_ a: NutrientSet, _ b: NutrientSet) -> NutrientSet { a.adding(b) }
        for (i, a) in singles.enumerated() {
            entries.append((a, 1))
            for b in singles[i...] { entries.append((sum(a, b), 2)) }
        }
        let expected = entries.map { MacroFitFinder.penalty($0.0, itemCount: $0.1, goal: goal) }.sorted().prefix(5)
        let found = MacroFitFinder.find(in: barn, goal: goal, structure: .anyCombination(maxItems: 2), limit: 5)
        XCTAssertEqual(found.suggestions.map(\.penalty), Array(expected), "pruning must not change the best results")
    }

    func testFiltersApply() {
        let noMilk = MacroFitFinder.find(in: barn, goal: .fitting(remainingCalories: 600), filter: MenuFilter(excludedAllergens: [.milk]), structure: .anyCombination(maxItems: 2), limit: 20)
        for suggestion in noMilk.suggestions {
            for line in suggestion.lines { XCTAssertFalse(barn.item(id: line.itemID)!.allergens.contains(.milk), line.itemID) }
        }
        let vegan = MacroFitFinder.find(in: barn, goal: .fitting(remainingCalories: 500), filter: MenuFilter(requiredDiet: [.vegan]), structure: .anyCombination(maxItems: 2), limit: 20)
        for suggestion in vegan.suggestions {
            for line in suggestion.lines { XCTAssertTrue(barn.item(id: line.itemID)!.dietTags.contains(.vegan), line.itemID) }
        }
        XCTAssertFalse(vegan.suggestions.isEmpty)
        let sectioned = MacroFitFinder.find(in: barn, goal: .fitting(remainingCalories: 400), filter: MenuFilter(excludedSections: ["Drinks", "Sides"]), structure: .anyCombination(maxItems: 1), limit: 20)
        XCTAssertTrue(sectioned.suggestions.allSatisfy { barn.item(id: $0.lines[0].itemID)!.section != "Drinks" })
        let excluded = MacroFitFinder.find(in: barn, goal: .fitting(remainingCalories: 540), filter: MenuFilter(excludedItemIDs: ["burger-barn/classic-barn-burger"]), structure: .anyCombination(maxItems: 1))
        XCTAssertFalse(excluded.suggestions.contains { $0.lines.first?.itemID == "burger-barn/classic-barn-burger" })
        let onlyBurgers = MenuFilter(includedSections: ["Burgers"])
        XCTAssertTrue(onlyBurgers.allows(barn.item(id: "burger-barn/classic-barn-burger")!))
        XCTAssertFalse(onlyBurgers.allows(barn.item(id: "burger-barn/fries")!))
    }

    func testSlotStructureBuildsAMealOfOnePerSlot() {
        let goal = MacroGoal.fitting(remainingCalories: 1000, proteinMin: 40)
        let slots: [[String]] = [["Burgers", "Chicken"], ["Sides"], ["Drinks"]]
        let result = MacroFitFinder.find(in: barn, goal: goal, structure: .slots(slots), limit: 10)
        XCTAssertFalse(result.suggestions.isEmpty)
        for suggestion in result.suggestions {
            let sections = suggestion.lines.map { barn.item(id: $0.itemID)!.section }
            for section in Set(sections) { XCTAssertEqual(sections.filter { $0 == section }.count, 1, "at most one per slot: \(sections)") }
            XCTAssertTrue(sections.allSatisfy { ["Burgers", "Chicken", "Sides", "Drinks"].contains($0) })
        }
        XCTAssertTrue(result.suggestions[0].meetsGoal)
    }

    func testItemsWithoutMacrosAreSkippedAndCounted() {
        var restaurant = tiny()
        restaurant.items.append(MenuItem(id: "t/calories-only", name: "Calories Only", section: "Main", nutrients: NutrientSet([.energyKcal: 300])))
        let result = MacroFitFinder.find(in: restaurant, goal: MacroGoal(calories: 250...350), structure: .anyCombination(maxItems: 1))
        XCTAssertEqual(result.itemsConsidered, 3)
        XCTAssertEqual(result.itemsSkippedForMissingNutrition, 1)
        XCTAssertFalse(result.suggestions.contains { $0.lines.first?.itemID == "t/calories-only" })
    }

    func testEvaluationBudgetTruncates() {
        let result = MacroFitFinder.find(in: barn, goal: .fitting(remainingCalories: 700), structure: .anyCombination(maxItems: 3), evaluationBudget: 25)
        XCTAssertTrue(result.truncated)
        XCTAssertFalse(result.suggestions.isEmpty, "a truncated search still returns what it found")
    }

    func testDegenerateInputs() {
        XCTAssertTrue(MacroFitFinder.find(in: barn, goal: .fitting(remainingCalories: 600), structure: .anyCombination(maxItems: 0)).suggestions.isEmpty)
        let nothing = MacroFitFinder.find(in: barn, goal: .fitting(remainingCalories: 5), structure: .anyCombination(maxItems: 2))
        XCTAssertTrue(nothing.suggestions.isEmpty, "nothing fits under a calorie ceiling of 5.75 kcal")
        XCTAssertTrue(MacroFitFinder.find(in: barn, goal: MacroGoal(), filter: MenuFilter(excludedSections: Set(barn.sections))).suggestions.isEmpty)
    }

    func testPenaltyOrdering() {
        let goal = MacroGoal(calories: 500...600, proteinMin: 30, fatMax: 20)
        func set(_ k: Double, _ p: Double, _ c: Double, _ f: Double) -> NutrientSet { NutrientSet([.energyKcal: k, .protein: p, .carbohydrate: c, .fat: f]) }
        let ideal = MacroFitFinder.penalty(set(550, 35, 50, 15), itemCount: 1, goal: goal)
        let over = MacroFitFinder.penalty(set(700, 35, 50, 15), itemCount: 1, goal: goal)
        let under = MacroFitFinder.penalty(set(400, 35, 50, 15), itemCount: 1, goal: goal)
        let lowProtein = MacroFitFinder.penalty(set(550, 15, 50, 15), itemCount: 1, goal: goal)
        let fatty = MacroFitFinder.penalty(set(550, 35, 50, 30), itemCount: 1, goal: goal)
        XCTAssertLessThan(ideal, under)
        XCTAssertLessThan(under, over, "overshooting costs more than falling short by the same amount")
        XCTAssertLessThan(ideal, lowProtein)
        XCTAssertLessThan(ideal, fatty)
        XCTAssertTrue(MacroFitFinder.meetsGoal(set(550, 35, 50, 15), goal: goal))
        XCTAssertFalse(MacroFitFinder.meetsGoal(set(550, 35, 50, 25), goal: goal))
    }
}

final class TweakTests: XCTestCase {
    private let library = Fixtures.library()
    private var barn: Restaurant { library.restaurant(id: "burger-barn")! }

    func testSuggestsTheOptionThatBringsTheOrderIntoRange() {
        // 540 kcal burger against a 440-480 kcal window: dropping the cheese lands on 460.
        let goal = MacroGoal(calories: 440...480)
        let lines = [OrderLine(itemID: "burger-barn/classic-barn-burger")]
        let tweaks = TweakSuggester.suggest(for: lines, in: barn, goal: goal)
        XCTAssertEqual(tweaks.first?.action, .remove(optionName: "Cheese"))
        XCTAssertEqual(tweaks.first?.totals.calories, 460)
        XCTAssertGreaterThan(tweaks.first?.improvement ?? 0, 0.3)
        XCTAssertTrue(tweaks.contains { $0.action == .remove(optionName: "Barn Sauce") })
        XCTAssertFalse(tweaks.contains { if case .add = $0.action { return true } else { return false } }, "adding bacon makes it worse")
        // The suggestion carries the full tweaked order.
        XCTAssertEqual(MealBuilder.build(tweaks[0].lines, in: barn).totals, tweaks[0].totals)
    }

    func testSuggestsSwapsInSingleChoiceGroups() {
        let cafe = library.restaurant(id: "bean-there-coffee")!
        // Tall latte is 150 kcal; the goal wants 120-130. Nonfat milk saves 20 kcal (130).
        let goal = MacroGoal(calories: 120...135)
        let tweaks = TweakSuggester.suggest(for: [OrderLine(itemID: "bean-there-coffee/latte", variantID: "tall")], in: cafe, goal: goal)
        XCTAssertEqual(tweaks.first?.action, .swap(from: "2% Milk", to: "Nonfat Milk"))
        XCTAssertEqual(tweaks.first?.totals.calories, 130)
        XCTAssertFalse(tweaks.contains { $0.action == .remove(optionName: "2% Milk") }, "a required group cannot be emptied")
    }

    func testNothingToSuggestWhenAlreadyOnTarget() {
        let tweaks = TweakSuggester.suggest(for: [OrderLine(itemID: "burger-barn/classic-barn-burger")], in: barn, goal: MacroGoal(calories: 500...580))
        XCTAssertEqual(tweaks.filter { $0.improvement > 0.2 }.count, 0)
        XCTAssertTrue(TweakSuggester.suggest(for: [], in: barn, goal: MacroGoal(calories: 500...580)).isEmpty)
    }
}
