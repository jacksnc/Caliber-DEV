import XCTest
import FoodCore
@testable import RestaurantCore

final class DiffTests: XCTestCase {
    private let base = Fixtures.library()

    private func modified(_ edit: (inout RestaurantLibrary) -> Void) -> RestaurantLibrary {
        var copy = base
        edit(&copy)
        return copy
    }

    private func barnIndex(_ library: RestaurantLibrary) -> Int { library.restaurants.firstIndex { $0.id == "burger-barn" }! }

    func testIdenticalLibrariesHaveNoChanges() {
        XCTAssertTrue(LibraryDiff.diff(old: base, new: base).isEmpty)
    }

    func testReportsRestaurantsItemsNutrientsAllergensAndRenames() {
        let provenance = Provenance(kind: .demoFictional, sourceName: "t", license: .cc0, asOf: "2026-10")
        let new = modified { library in
            let b = barnIndex(library)
            library.restaurants.removeAll { $0.id == "taco-tangent" }
            library.restaurants.append(Restaurant(id: "new-place", name: "New Place", provenance: provenance))

            var burger = library.restaurants[b].items.firstIndex { $0.id == "burger-barn/classic-barn-burger" }!
            library.restaurants[b].items[burger].nutrients[.energyKcal] = 520
            library.restaurants[b].items[burger].nutrients[.sodium] = 1000
            library.restaurants[b].items[burger].nutrients[.protein] = 28.05    // under the 0.1 g noise floor

            library.restaurants[b].items.removeAll { $0.id == "burger-barn/side-salad" }
            library.restaurants[b].items.append(MenuItem(id: "burger-barn/spicy-chicken", name: "Spicy Chicken", section: "Chicken",
                                                         nutrients: NutrientSet([.energyKcal: 600])))
            burger = library.restaurants[b].items.firstIndex { $0.id == "burger-barn/cola" }!
            library.restaurants[b].items[burger].name = "Cola Classic"

            let fries = library.restaurants[b].items.firstIndex { $0.id == "burger-barn/fries" }!
            library.restaurants[b].items[fries].allergens.insert(.sesame)
            library.restaurants[b].items[fries].variants[2].nutrients?[.energyKcal] = 460
        }

        let changes = LibraryDiff.diff(old: base, new: new)
        XCTAssertEqual(changes.addedRestaurants, ["new-place"])
        XCTAssertEqual(changes.removedRestaurants, ["taco-tangent"])
        XCTAssertEqual(changes.changedRestaurants.map(\.restaurantID), ["burger-barn"])
        XCTAssertEqual(changes.itemChangeCount, 5)

        let items = Dictionary(uniqueKeysWithValues: changes.changedRestaurants[0].items.map { ($0.itemID, $0) })
        let burger = items["burger-barn/classic-barn-burger"]
        XCTAssertEqual(burger?.status, .modified)
        XCTAssertEqual(Set(burger?.nutrientChanges.map(\.nutrient) ?? []), [.energyKcal, .sodium], "28 g -> 28.05 g is below the noise floor")
        XCTAssertEqual(burger?.nutrientChanges.first { $0.nutrient == .energyKcal }, NutrientChange(nutrient: .energyKcal, variantID: nil, old: 540, new: 520))
        XCTAssertEqual(items["burger-barn/side-salad"]?.status, .removed)
        XCTAssertEqual(items["burger-barn/spicy-chicken"]?.status, .added)
        XCTAssertEqual(items["burger-barn/cola"]?.renamedFrom, "Cola")
        XCTAssertEqual(items["burger-barn/cola"]?.nutrientChanges, [])
        XCTAssertEqual(items["burger-barn/fries"]?.allergensAdded, [.sesame])
        XCTAssertEqual(items["burger-barn/fries"]?.nutrientChanges, [NutrientChange(nutrient: .energyKcal, variantID: "large", old: 450, new: 460)])
    }

    func testVariantAddedOrRemovedIsReported() {
        let new = modified { library in
            let b = barnIndex(library)
            let cola = library.restaurants[b].items.firstIndex { $0.id == "burger-barn/cola" }!
            library.restaurants[b].items[cola].variants.append(ItemVariant(id: "xl", name: "XL", nutrients: NutrientSet([.energyKcal: 400])))
        }
        let changes = LibraryDiff.diff(old: base, new: new)
        let change = changes.changedRestaurants.first?.items.first
        XCTAssertEqual(change?.nutrientChanges, [NutrientChange(nutrient: .energyKcal, variantID: "xl", old: nil, new: 400)])
    }
}

final class OverlayTests: XCTestCase {
    private let base = Fixtures.library()
    private let burgerID = "burger-barn/classic-barn-burger"

    private func burger(in library: RestaurantLibrary) -> MenuItem { library.item(id: burgerID)!.item }

    func testFingerprintGoldenAndSensitivity() {
        let item = MenuItem(id: "x/a", name: "A", section: "S", nutrients: NutrientSet([.energyKcal: 100, .protein: 5.5]))
        XCTAssertEqual(ItemFingerprint.of(item), "e532feb959bbb4b0", "FNV-1a of \"energyKcal:100.00,protein:5.50\"")
        var renamed = item
        renamed.name = "Different"
        renamed.allergens = [.milk]
        XCTAssertEqual(ItemFingerprint.of(renamed), ItemFingerprint.of(item), "names and allergens are not part of the nutrition fingerprint")
        var changed = item
        changed.nutrients[.energyKcal] = 101
        XCTAssertNotEqual(ItemFingerprint.of(changed), ItemFingerprint.of(item))
        var sized = item
        sized.variants = [ItemVariant(id: "l", name: "L", nutrients: NutrientSet([.energyKcal: 200]))]
        XCTAssertNotEqual(ItemFingerprint.of(sized), ItemFingerprint.of(item))
    }

    func testOverrideIsAppliedAndSurvivesUnchangedLibrary() {
        var overlay = UserOverlay()
        var mine = burger(in: base).nutrients
        mine[.energyKcal] = 500
        overlay.setOverride(for: burger(in: base), nutrients: mine, note: "no bun swap")

        let view = overlay.applied(to: base)
        XCTAssertEqual(view.item(id: burgerID)?.item.nutrients.calories, 500)
        XCTAssertEqual(view.item(id: "burger-barn/fries")?.item.nutrients.calories, 230, "other items untouched")
        XCTAssertEqual(base.item(id: burgerID)?.item.nutrients.calories, 540, "the shipped library is never mutated")
        XCTAssertEqual(overlay.states(in: base)[burgerID], .current)
    }

    func testLibraryUpdateFlagsOverrideAndUserDecides() {
        var overlay = UserOverlay()
        overlay.setOverride(for: burger(in: base), nutrients: NutrientSet([.energyKcal: 500, .protein: 28, .carbohydrate: 40, .fat: 27]))

        var updated = base
        let b = updated.restaurants.firstIndex { $0.id == "burger-barn" }!
        let i = updated.restaurants[b].items.firstIndex { $0.id == burgerID }!
        updated.restaurants[b].items[i].nutrients[.energyKcal] = 530

        XCTAssertEqual(overlay.states(in: updated)[burgerID], .baseChanged)
        XCTAssertEqual(overlay.applied(to: updated).item(id: burgerID)?.item.nutrients.calories, 500, "the user's numbers stay in force until they decide")

        var keep = overlay
        keep.resolve(itemID: burgerID, resolution: .keepMine, in: updated)
        XCTAssertEqual(keep.states(in: updated)[burgerID], .current)
        XCTAssertEqual(keep.applied(to: updated).item(id: burgerID)?.item.nutrients.calories, 500)

        var useLibrary = overlay
        useLibrary.resolve(itemID: burgerID, resolution: .useLibrary, in: updated)
        XCTAssertTrue(useLibrary.overrides.isEmpty)
        XCTAssertEqual(useLibrary.applied(to: updated).item(id: burgerID)?.item.nutrients.calories, 530)
    }

    func testOrphanedOverrideAndHarmlessResolve() {
        var overlay = UserOverlay()
        overlay.setOverride(for: burger(in: base), nutrients: NutrientSet([.energyKcal: 500]))
        var shrunk = base
        shrunk.restaurants.removeAll { $0.id == "burger-barn" }
        XCTAssertEqual(overlay.states(in: shrunk)[burgerID], .orphaned)
        XCTAssertEqual(overlay.applied(to: shrunk).restaurants.count, 2)
        overlay.resolve(itemID: "unknown", resolution: .keepMine, in: shrunk)
        overlay.resolve(itemID: burgerID, resolution: .keepMine, in: shrunk)
        XCTAssertEqual(overlay.states(in: shrunk)[burgerID], .orphaned, "nothing to re-base on")
        overlay.removeOverride(itemID: burgerID)
        XCTAssertTrue(overlay.overrides.isEmpty)
    }

    func testCustomItemsAndRestaurants() {
        var overlay = UserOverlay()
        overlay.addCustomItem(MenuItem(id: "burger-barn/my-combo", name: "My Combo", section: "Custom", nutrients: NutrientSet([.energyKcal: 700, .protein: 40, .carbohydrate: 60, .fat: 30])), toRestaurant: "burger-barn")
        overlay.addCustomItem(MenuItem(id: "burger-barn/my-combo", name: "My Combo v2", section: "Custom", nutrients: NutrientSet([.energyKcal: 650])), toRestaurant: "burger-barn")
        overlay.addCustomRestaurant(Restaurant(id: "user/joes-diner", name: "Joe's Diner", provenance: Provenance(kind: .userContributed, sourceName: "You", license: .userOwned, asOf: "2026-10")))

        let view = overlay.applied(to: base)
        let barn = view.restaurant(id: "burger-barn")!
        XCTAssertEqual(barn.items.filter { $0.id == "burger-barn/my-combo" }.count, 1, "re-adding replaces")
        XCTAssertEqual(barn.item(id: "burger-barn/my-combo")?.name, "My Combo v2")
        XCTAssertEqual(barn.item(id: "burger-barn/my-combo")?.provenance?.kind, .userContributed)
        XCTAssertNotNil(view.restaurant(id: "user/joes-diner"))
        XCTAssertEqual(view.restaurants.count, 4)
    }

    func testOverlayCodableRoundTrip() throws {
        var overlay = UserOverlay()
        overlay.setOverride(for: burger(in: base), nutrients: NutrientSet([.energyKcal: 500]), note: "n")
        overlay.addCustomRestaurant(Restaurant(id: "user/x", name: "X", provenance: Provenance(kind: .userContributed, sourceName: "You", license: .userOwned, asOf: "")))
        let decoded = try JSONDecoder().decode(UserOverlay.self, from: JSONEncoder().encode(overlay))
        XCTAssertEqual(decoded, overlay)
    }
}

final class AttributionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_792_800_000)   // 2026-10-24

    func testCreditsGroupBySourceAndLicense() {
        var library = Fixtures.library()
        let b = library.restaurants.firstIndex { $0.id == "burger-barn" }!
        library.restaurants[b].items[0].provenance = Provenance(kind: .licensedAPI, sourceName: "Menu Data Co", sourceURL: "https://example.invalid", license: .licensedCommercial, asOf: "2026-09")
        let credits = LibraryAttribution.credits(for: library)
        XCTAssertEqual(credits.count, 2)
        XCTAssertEqual(credits[0].sourceName, "Helios fictional demo menus")
        XCTAssertEqual(credits[0].itemCount, 14)
        XCTAssertEqual(credits[0].restaurantCount, 3)
        XCTAssertEqual(credits[1].sourceName, "Menu Data Co")
        XCTAssertEqual(credits[1].itemCount, 1)
        XCTAssertEqual(credits[1].license, .licensedCommercial)
        XCTAssertEqual(credits[1].sourceURL, "https://example.invalid")
    }

    func testWarningsFlagDemoDataUnknownLicensesShareAlikeAndStaleMenus() {
        let library = Fixtures.library()
        let warnings = LibraryAttribution.warnings(for: library, now: now)
        XCTAssertEqual(warnings.filter { if case .containsDemoData = $0 { return true } else { return false } }.count, 3, "demo data must be removed before release")
        XCTAssertFalse(warnings.contains { if case .staleMenu = $0 { return true } else { return false } })

        let later = Date(timeIntervalSince1970: 1_792_800_000 + 2 * 365 * 86_400)
        XCTAssertTrue(LibraryAttribution.warnings(for: library, now: later).contains(.staleMenu(restaurantID: "burger-barn", asOf: "2026-10")))

        var risky = library
        risky.restaurants[0].provenance = Provenance(kind: .governmentDataset, sourceName: "Open Menu Project", license: .odbl, asOf: "2026-10")
        risky.restaurants[1].provenance = Provenance(kind: .officialChain, sourceName: "Scraped", license: .unknown, asOf: "2026-10")
        let riskyWarnings = LibraryAttribution.warnings(for: risky, now: now)
        XCTAssertTrue(riskyWarnings.contains(.shareAlikeSource(sourceName: "Open Menu Project")))
        XCTAssertTrue(riskyWarnings.contains(.unknownLicense(restaurantID: "taco-tangent")))
    }

    func testMonthMath() {
        XCTAssertEqual(LibraryAttribution.monthsSince("2026-10", now: now), 0)
        XCTAssertEqual(LibraryAttribution.monthsSince("2025-10-01", now: now), 12)
        XCTAssertEqual(LibraryAttribution.monthsSince("2026-01", now: now), 9)
        XCTAssertNil(LibraryAttribution.monthsSince("unknown", now: now))
        XCTAssertNil(LibraryAttribution.monthsSince("2026-13", now: now))
    }
}

final class EstimatorTests: XCTestCase {
    private let protein = EstimateComponent(name: "Test protein", grams: 100...200, typicalGrams: 150,
                                            per100g: NutrientSet([.energyKcal: 160, .protein: 30, .carbohydrate: 0, .fat: 4]))
    private let starch = EstimateComponent(name: "Test starch", grams: 150...250, typicalGrams: 200,
                                           per100g: NutrientSet([.energyKcal: 130, .protein: 3, .carbohydrate: 28, .fat: 0.5]))
    private let panFried = CookingMethod(name: "Pan-fried", addedFatGrams: 5...15, typicalFatGrams: 10)

    func testRangeArithmeticForAChainDish() {
        let estimate = DishEstimator.estimate(components: [protein, starch], cooking: [panFried], venue: .chainPublished)
        // typical: 240 + 260 + 90 = 590 kcal, 51 g protein, 56 g carbs, 17 g fat
        XCTAssertEqual(estimate.typical.calories, 590)
        XCTAssertEqual(estimate.typical.proteinG, 51)
        XCTAssertEqual(estimate.typical.carbsG, 56)
        XCTAssertEqual(estimate.typical.fatG, 17)
        // low (100 g + 150 g + 5 g oil) = 400 kcal; high (200 g + 250 g + 15 g oil) = 780 kcal; widened by 8%
        XCTAssertEqual(estimate.low.calories ?? 0, 400 * 0.92, accuracy: 1e-6)
        XCTAssertEqual(estimate.high.calories ?? 0, 780 * 1.08, accuracy: 1e-6)
        XCTAssertEqual(estimate.low.proteinG ?? 0, 34.5 * 0.92, accuracy: 1e-6)
        XCTAssertEqual(estimate.high.fatG ?? 0, 24.25 * 1.08, accuracy: 1e-6)
    }

    func testIndependentVenuesGetWiderRanges() {
        let chain = DishEstimator.estimate(components: [protein, starch], cooking: [panFried], venue: .chainPublished)
        let independent = DishEstimator.estimate(components: [protein, starch], cooking: [panFried], venue: .independent)
        let buffet = DishEstimator.estimate(components: [protein, starch], cooking: [panFried], venue: .buffet)
        XCTAssertEqual(independent.low.calories ?? 0, 300, accuracy: 1e-6)
        XCTAssertEqual(independent.high.calories ?? 0, 975, accuracy: 1e-6)
        XCTAssertEqual(independent.typical, chain.typical, "the typical value does not move")
        XCTAssertLessThan(buffet.low.calories ?? 0, independent.low.calories ?? 0)
        XCTAssertGreaterThan(buffet.high.calories ?? 0, independent.high.calories ?? 0)
        XCTAssertTrue(independent.assumptions.contains("Venue uncertainty 25% (independent)"))
        XCTAssertTrue(independent.assumptions.contains("Test protein: 100-200 g"))
        XCTAssertTrue(independent.assumptions.contains("Pan-fried: 5-15 g added fat"))
    }

    func testPortionScaleAndLoggingPolicies() {
        let half = DishEstimator.estimate(components: [protein, starch], cooking: [panFried], portionScale: 0.5, venue: .independent)
        XCTAssertEqual(half.typical.calories, 295)
        XCTAssertTrue(half.assumptions.contains("Portion scaled by 0.5"))

        let full = DishEstimator.estimate(components: [protein, starch], cooking: [panFried], venue: .independent)
        XCTAssertEqual(full.logged(.typical).calories, 590)
        XCTAssertEqual(full.logged(.conservative(share: 0.5)).calories ?? 0, 782.5, accuracy: 1e-6)
        XCTAssertEqual(full.logged(.conservative(share: 1)).calories ?? 0, 975, accuracy: 1e-6)
        XCTAssertEqual(full.logged(.conservative(share: 5)).calories ?? 0, 975, accuracy: 1e-6, "share is clamped")
        XCTAssertEqual(full.provenance.kind, .estimated)
    }

    func testNoComponentsGivesAnEmptyEstimate() {
        let estimate = DishEstimator.estimate(components: [], venue: .independent)
        XCTAssertTrue(estimate.typical.isEmpty)
    }
}

final class BrowserTests: XCTestCase {
    private let barn = Fixtures.library().restaurant(id: "burger-barn")!

    func testProteinDensityRanking() {
        let rows = MenuBrowser.rows(in: barn, sort: .proteinPer100kcal, limit: 4)
        XCTAssertEqual(rows.map(\.itemID), ["burger-barn/double-barn-burger", "burger-barn/classic-barn-burger", "burger-barn/crispy-chicken-sandwich", "burger-barn/garden-veggie-burger"])
        XCTAssertEqual(rows[0].proteinPer100kcal, 49.0 / 780 * 100, accuracy: 1e-9)
    }

    func testFiltersAndVariantRows() {
        let picks = MenuBrowser.rows(in: barn, maxCalories: 600, minProtein: 20, sort: .proteinPer100kcal)
        XCTAssertEqual(picks.map(\.itemID), ["burger-barn/classic-barn-burger", "burger-barn/crispy-chicken-sandwich", "burger-barn/garden-veggie-burger"])

        let sides = MenuBrowser.rows(in: barn, filter: MenuFilter(includedSections: ["Sides"]), sort: .caloriesAscending)
        XCTAssertEqual(sides.map(\.name), ["Side Salad", "Fries (Small)", "Fries (Medium)", "Fries (Large)"])
        XCTAssertEqual(sides[1].variantID, "small")

        let lowSodium = MenuBrowser.rows(in: barn, maxSodium: 200, sort: .name)
        XCTAssertEqual(lowSodium.map(\.name), ["Cola (Large)", "Cola (Small)", "Fries (Small)", "Side Salad"])
    }

    func testSortsAndLimit() {
        XCTAssertEqual(MenuBrowser.rows(in: barn, sort: .caloriesDescending, limit: 1).first?.itemID, "burger-barn/double-barn-burger")
        XCTAssertEqual(MenuBrowser.rows(in: barn, sort: .protein, limit: 1).first?.itemID, "burger-barn/double-barn-burger")
        XCTAssertEqual(MenuBrowser.rows(in: barn, sort: .carbsAscending, limit: 1).first?.name, "Side Salad")
        XCTAssertEqual(MenuBrowser.rows(in: barn, sort: .name, limit: 2).map(\.name), ["Chocolate Shake", "Classic Barn Burger"])
        XCTAssertEqual(MenuBrowser.rows(in: barn, filter: MenuFilter(requiredDiet: [.vegan]), sort: .fatAscending, limit: 1).first?.name, "Cola (Large)")
    }
}
