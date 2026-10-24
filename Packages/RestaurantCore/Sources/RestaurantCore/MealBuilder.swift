import Foundation
import FoodCore

/// One thing ordered: an item, optionally a size, with the customer's modifier choices.
public struct OrderLine: Equatable, Sendable {
    public var itemID: String
    public var variantID: String?
    /// Chosen option IDs per modifier group. A group that is not listed keeps its default options.
    public var selections: [String: Set<String>]
    /// Fractions are allowed ("half the fries").
    public var quantity: Double

    public init(itemID: String, variantID: String? = nil, selections: [String: Set<String>] = [:], quantity: Double = 1) {
        self.itemID = itemID
        self.variantID = variantID
        self.selections = selections
        self.quantity = quantity
    }
}

public enum MealWarning: Equatable, Sendable {
    case unknownItem(String)
    case unknownVariant(item: String, variant: String)
    case unknownGroup(item: String, group: String)
    case unknownOption(group: String, option: String)
    /// More than one choice in a single-choice group, an empty required group, or too many extras.
    case ruleViolated(group: String)
    /// Removing options would have taken a nutrient below zero; it was clamped to zero.
    case clampedNegative(Nutrient)
}

public struct LineResult: Equatable, Sendable {
    public let line: OrderLine
    public let item: MenuItem?
    /// Nutrition of the whole line (quantity applied). Empty when the item is unknown.
    public let nutrients: NutrientSet
    public let warnings: [MealWarning]
}

public struct Meal: Equatable, Sendable {
    public let lines: [LineResult]
    public let totals: NutrientSet
    /// Nutrients that at least one line does not report, so the matching total is a lower bound.
    public let incomplete: Set<Nutrient>

    public var warnings: [MealWarning] { lines.flatMap(\.warnings) }
}

public enum MealBuilder {
    public static func build(_ lines: [OrderLine], in restaurant: Restaurant) -> Meal {
        let results = lines.map { nutrients(for: $0, in: restaurant) }
        let known = results.filter { $0.item != nil }

        var totals: [Nutrient: Double] = [:]
        var present: [Nutrient: Int] = [:]
        for result in known {
            for nutrient in result.nutrients.nutrients {
                totals[nutrient, default: 0] += result.nutrients[nutrient] ?? 0
                present[nutrient, default: 0] += 1
            }
        }
        let incomplete = Set(present.filter { $0.value < known.count }.keys)
        let cleaned = totals.mapValues { ($0 * 1e6).rounded() / 1e6 }
        return Meal(lines: results, totals: NutrientSet(cleaned), incomplete: incomplete)
    }

    /// Nutrition of one order line: the chosen size, then modifier choices applied against the listed build.
    public static func nutrients(for line: OrderLine, in restaurant: Restaurant) -> LineResult {
        guard let item = restaurant.item(id: line.itemID) else {
            return LineResult(line: line, item: nil, nutrients: NutrientSet(), warnings: [.unknownItem(line.itemID)])
        }
        var warnings: [MealWarning] = []

        if let variantID = line.variantID, !item.variants.contains(where: { $0.id == variantID }) {
            warnings.append(.unknownVariant(item: item.id, variant: variantID))
        }
        let base = item.baseNutrients(variantID: line.variantID)

        var delta: [Nutrient: Double] = [:]
        for (groupID, chosen) in line.selections.sorted(by: { $0.key < $1.key }) {
            guard item.modifierGroupIDs.contains(groupID), let group = restaurant.group(id: groupID) else {
                warnings.append(.unknownGroup(item: item.id, group: groupID))
                continue
            }
            let optionIDs = Set(group.options.map(\.id))
            for unknown in chosen.subtracting(optionIDs).sorted() { warnings.append(.unknownOption(group: groupID, option: unknown)) }
            let valid = chosen.intersection(optionIDs)

            switch group.rule {
            case let .single(required):
                if valid.count > 1 || (required && valid.isEmpty) { warnings.append(.ruleViolated(group: groupID)) }
            case let .multiple(max):
                if let max, valid.count > max { warnings.append(.ruleViolated(group: groupID)) }
            }

            let defaults = group.defaultOptionIDs
            for option in group.options {
                let sign: Double
                if valid.contains(option.id), !defaults.contains(option.id) { sign = 1 }
                else if !valid.contains(option.id), defaults.contains(option.id) { sign = -1 }
                else { continue }
                for nutrient in option.delta.nutrients {
                    delta[nutrient, default: 0] += sign * (option.delta[nutrient] ?? 0)
                }
            }
        }

        // Deltas only apply to nutrients the item actually reports; an unknown value stays unknown.
        var adjusted = base
        for (nutrient, change) in delta {
            guard let current = base[nutrient] else { continue }
            let value = current + change
            if value < -1e-9 { warnings.append(.clampedNegative(nutrient)) }
            adjusted[nutrient] = max(0, (value * 1e6).rounded() / 1e6)
        }
        warnings.sort { "\($0)" < "\($1)" }
        return LineResult(line: line, item: item, nutrients: adjusted.scaled(by: line.quantity), warnings: warnings)
    }

    /// Selections that spell out the listed build explicitly (useful as a starting point for a customise screen).
    public static func defaultSelections(for item: MenuItem, in restaurant: Restaurant) -> [String: Set<String>] {
        var result: [String: Set<String>] = [:]
        for id in item.modifierGroupIDs {
            if let group = restaurant.group(id: id) { result[id] = group.defaultOptionIDs }
        }
        return result
    }
}
