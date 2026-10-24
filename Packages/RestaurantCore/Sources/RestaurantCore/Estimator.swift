import Foundation
import FoodCore

/// How much to trust a recipe. The width is added on top of the portion range because hidden oil, butter and sugar
/// vary far more between kitchens than between servings of a published recipe. These are heuristics, not measurements.
public enum VenueType: String, Codable, Sendable, CaseIterable {
    case chainPublished
    case fastCasual
    case independent
    case buffet

    public var uncertainty: Double {
        switch self {
        case .chainPublished: return 0.08
        case .fastCasual: return 0.15
        case .independent: return 0.25
        case .buffet: return 0.35
        }
    }
}

/// One part of a dish, with a plausible weight range and its nutrition per 100 g (from a generic food record).
public struct EstimateComponent: Equatable, Sendable {
    public var name: String
    public var grams: ClosedRange<Double>
    public var typicalGrams: Double
    public var per100g: NutrientSet

    public init(name: String, grams: ClosedRange<Double>, typicalGrams: Double, per100g: NutrientSet) {
        self.name = name
        self.grams = grams
        self.typicalGrams = typicalGrams
        self.per100g = per100g
    }
}

/// Fat added by the cooking method (pan-fried, deep-fried, buttered), in grams.
public struct CookingMethod: Equatable, Sendable {
    public var name: String
    public var addedFatGrams: ClosedRange<Double>
    public var typicalFatGrams: Double

    public init(name: String, addedFatGrams: ClosedRange<Double>, typicalFatGrams: Double) {
        self.name = name
        self.addedFatGrams = addedFatGrams
        self.typicalFatGrams = typicalFatGrams
    }
}

public enum LoggingPolicy: Equatable, Sendable {
    case typical
    /// Log part of the way from typical to high, because under-logging restaurant food is the common error.
    case conservative(share: Double)
}

public struct DishEstimate: Equatable, Sendable {
    public let low: NutrientSet
    public let typical: NutrientSet
    public let high: NutrientSet
    public let assumptions: [String]

    /// The numbers to put in the diary under `policy`.
    public func logged(_ policy: LoggingPolicy) -> NutrientSet {
        switch policy {
        case .typical:
            return typical
        case let .conservative(share):
            let weight = min(max(share, 0), 1)
            var result = NutrientSet()
            for nutrient in typical.nutrients {
                let t = typical[nutrient] ?? 0
                result[nutrient] = NutrientSet.clean(t + weight * ((high[nutrient] ?? t) - t))
            }
            return result
        }
    }

    public var provenance: Provenance {
        Provenance(kind: .estimated, sourceName: "Helios dish estimator", license: .userOwned, asOf: "")
    }
}

/// Builds a calorie and macro range for a dish with no published nutrition (a local restaurant) from its parts.
/// Component data is supplied by the caller (typically generic USDA records); nothing here is a database of dishes.
public enum DishEstimator {
    public static func estimate(
        components: [EstimateComponent],
        cooking: [CookingMethod] = [],
        portionScale: Double = 1,
        venue: VenueType
    ) -> DishEstimate {
        func sum(_ pick: (EstimateComponent) -> Double, fat: (CookingMethod) -> Double) -> NutrientSet {
            var total = NutrientSet()
            for component in components {
                let grams = pick(component)
                for nutrient in component.per100g.nutrients {
                    total[nutrient] = (total[nutrient] ?? 0) + (component.per100g[nutrient] ?? 0) * grams / 100
                }
            }
            for method in cooking {
                let added = fat(method)
                // Oil and butter are essentially pure fat at 9 kcal/g.
                total[.fat] = (total[.fat] ?? 0) + added
                total[.energyKcal] = (total[.energyKcal] ?? 0) + 9 * added
            }
            return total
        }

        let u = venue.uncertainty
        let typical = sum({ $0.typicalGrams }, fat: { $0.typicalFatGrams })
        let low = sum({ $0.grams.lowerBound }, fat: { $0.addedFatGrams.lowerBound })
        let high = sum({ $0.grams.upperBound }, fat: { $0.addedFatGrams.upperBound })

        var assumptions = components.map { "\($0.name): \(Int($0.grams.lowerBound))-\(Int($0.grams.upperBound)) g" }
        assumptions += cooking.map { "\($0.name): \(Int($0.addedFatGrams.lowerBound))-\(Int($0.addedFatGrams.upperBound)) g added fat" }
        assumptions.append("Venue uncertainty \(Int(u * 100))% (\(venue.rawValue))")
        if portionScale != 1 { assumptions.append("Portion scaled by \(portionScale)") }

        return DishEstimate(
            low: low.scaled(by: portionScale * (1 - u)),
            typical: typical.scaled(by: portionScale),
            high: high.scaled(by: portionScale * (1 + u)),
            assumptions: assumptions
        )
    }
}

// MARK: Browsing

public enum MenuSort: Equatable, Sendable {
    case proteinPer100kcal
    case caloriesAscending
    case caloriesDescending
    case protein
    case carbsAscending
    case fatAscending
    case name
}

public struct MenuRow: Equatable, Sendable {
    public let itemID: String
    public let variantID: String?
    public let name: String
    public let nutrients: NutrientSet

    public var proteinPer100kcal: Double {
        (nutrients.proteinG ?? 0) / max(nutrients.calories ?? 0, 1) * 100
    }
}

/// "High-protein picks under 600 calories": sorted, filtered rows for browsing a menu by numbers.
public enum MenuBrowser {
    public static func rows(
        in restaurant: Restaurant,
        filter: MenuFilter = MenuFilter(),
        maxCalories: Double? = nil,
        minProtein: Double? = nil,
        maxCarbs: Double? = nil,
        maxFat: Double? = nil,
        maxSodium: Double? = nil,
        sort: MenuSort = .name,
        limit: Int = 50
    ) -> [MenuRow] {
        var rows: [MenuRow] = []
        for item in restaurant.items where filter.allows(item) {
            let entries: [(String?, String, NutrientSet)] = item.variants.isEmpty
                ? [(nil, item.name, item.nutrients)]
                : item.variants.map { ($0.id, "\(item.name) (\($0.name))", item.baseNutrients(variantID: $0.id)) }
            for (variantID, name, nutrients) in entries {
                guard let calories = nutrients.calories else { continue }
                if let maxCalories, calories > maxCalories { continue }
                if let minProtein, (nutrients.proteinG ?? 0) < minProtein { continue }
                if let maxCarbs, let carbs = nutrients.carbsG, carbs > maxCarbs { continue }
                if let maxFat, let fat = nutrients.fatG, fat > maxFat { continue }
                if let maxSodium, let sodium = nutrients[.sodium], sodium > maxSodium { continue }
                rows.append(MenuRow(itemID: item.id, variantID: variantID, name: name, nutrients: nutrients))
            }
        }
        rows.sort { lhs, rhs in
            let order: Bool?
            switch sort {
            case .proteinPer100kcal: order = lhs.proteinPer100kcal == rhs.proteinPer100kcal ? nil : lhs.proteinPer100kcal > rhs.proteinPer100kcal
            case .caloriesAscending: order = lhs.nutrients.calories == rhs.nutrients.calories ? nil : (lhs.nutrients.calories ?? 0) < (rhs.nutrients.calories ?? 0)
            case .caloriesDescending: order = lhs.nutrients.calories == rhs.nutrients.calories ? nil : (lhs.nutrients.calories ?? 0) > (rhs.nutrients.calories ?? 0)
            case .protein: order = lhs.nutrients.proteinG == rhs.nutrients.proteinG ? nil : (lhs.nutrients.proteinG ?? 0) > (rhs.nutrients.proteinG ?? 0)
            case .carbsAscending: order = lhs.nutrients.carbsG == rhs.nutrients.carbsG ? nil : (lhs.nutrients.carbsG ?? .infinity) < (rhs.nutrients.carbsG ?? .infinity)
            case .fatAscending: order = lhs.nutrients.fatG == rhs.nutrients.fatG ? nil : (lhs.nutrients.fatG ?? .infinity) < (rhs.nutrients.fatG ?? .infinity)
            case .name: order = nil
            }
            if let order { return order }
            return lhs.name != rhs.name ? lhs.name < rhs.name : lhs.itemID < rhs.itemID
        }
        return Array(rows.prefix(limit))
    }
}
