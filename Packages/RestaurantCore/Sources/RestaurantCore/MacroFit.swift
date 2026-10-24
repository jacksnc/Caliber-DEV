import Foundation
import FoodCore

/// What the user has left to eat. Calories are a window; protein and fibre are minimums; the rest are ceilings.
public struct MacroGoal: Equatable, Sendable {
    public var calories: ClosedRange<Double>?
    public var proteinMin: Double?
    public var fiberMin: Double?
    public var carbsMax: Double?
    public var fatMax: Double?
    public var sodiumMax: Double?

    public init(
        calories: ClosedRange<Double>? = nil,
        proteinMin: Double? = nil,
        fiberMin: Double? = nil,
        carbsMax: Double? = nil,
        fatMax: Double? = nil,
        sodiumMax: Double? = nil
    ) {
        self.calories = calories
        self.proteinMin = proteinMin
        self.fiberMin = fiberMin
        self.carbsMax = carbsMax
        self.fatMax = fatMax
        self.sodiumMax = sodiumMax
    }

    /// A window of `remaining` calories, `tolerance` either side, e.g. 600 kcal left -> 540...660.
    public static func fitting(remainingCalories remaining: Double, tolerance: Double = 0.1, proteinMin: Double? = nil, carbsMax: Double? = nil, fatMax: Double? = nil) -> MacroGoal {
        MacroGoal(calories: (remaining * (1 - tolerance))...(remaining * (1 + tolerance)), proteinMin: proteinMin, carbsMax: carbsMax, fatMax: fatMax)
    }
}

/// Which menu items may be suggested.
public struct MenuFilter: Equatable, Sendable {
    public var excludedAllergens: Set<Allergen>
    public var requiredDiet: Set<DietTag>
    public var excludedSections: Set<String>
    public var includedSections: Set<String>?
    public var excludedItemIDs: Set<String>

    public init(
        excludedAllergens: Set<Allergen> = [],
        requiredDiet: Set<DietTag> = [],
        excludedSections: Set<String> = [],
        includedSections: Set<String>? = nil,
        excludedItemIDs: Set<String> = []
    ) {
        self.excludedAllergens = excludedAllergens
        self.requiredDiet = requiredDiet
        self.excludedSections = excludedSections
        self.includedSections = includedSections
        self.excludedItemIDs = excludedItemIDs
    }

    public func allows(_ item: MenuItem) -> Bool {
        if !excludedAllergens.isDisjoint(with: item.allergens) { return false }
        if !requiredDiet.isSubset(of: item.dietTags) { return false }
        if excludedSections.contains(item.section) { return false }
        if let includedSections, !includedSections.contains(item.section) { return false }
        return !excludedItemIDs.contains(item.id)
    }
}

public struct FitSuggestion: Equatable, Sendable {
    public let lines: [OrderLine]
    public let totals: NutrientSet
    /// Lower is better; zero means every constraint is met. Tiny preferences (protein density, fewer items) can
    /// push it fractionally below zero.
    public let penalty: Double
    public let meetsGoal: Bool
}

public struct FitResult: Equatable, Sendable {
    public let suggestions: [FitSuggestion]
    public let itemsConsidered: Int
    /// Items left out because calories or a macro are not published for them.
    public let itemsSkippedForMissingNutrition: Int
    /// True when the evaluation budget ran out before every combination was tried.
    public let truncated: Bool
}

public enum MacroFitFinder {
    public enum Structure: Equatable, Sendable {
        /// Any mix of up to `maxItems` items (repeats allowed: two tacos).
        case anyCombination(maxItems: Int)
        /// At most one item from each slot, where a slot is a list of menu sections: ["Burgers", "Chicken"], ["Sides"], ["Drinks"].
        case slots([[String]])
    }

    struct Candidate {
        let itemID: String
        let variantID: String?
        let nutrients: NutrientSet
        let section: String
    }

    // MARK: Scoring

    /// How far `totals` is from the goal. Overshooting calories, carbs, fat and sodium costs more than falling short,
    /// and a protein shortfall costs more than anything: the meal should still do its job.
    static func penalty(_ totals: NutrientSet, itemCount: Int, goal: MacroGoal) -> Double {
        var penalty = 0.0
        let calories = totals.calories ?? 0
        if let window = goal.calories {
            let center = max((window.lowerBound + window.upperBound) / 2, 1)
            if calories < window.lowerBound { penalty += (window.lowerBound - calories) / center }
            if calories > window.upperBound { penalty += 3 * (calories - window.upperBound) / center }
        }
        if let minimum = goal.proteinMin, minimum > 0 {
            penalty += 2 * max(0, minimum - (totals.proteinG ?? 0)) / minimum
        }
        if let minimum = goal.fiberMin, minimum > 0 {
            penalty += 0.5 * max(0, minimum - (totals[.fiber] ?? 0)) / minimum
        }
        for (maximum, value) in [(goal.carbsMax, totals.carbsG), (goal.fatMax, totals.fatG), (goal.sodiumMax, totals[.sodium])] {
            if let maximum, maximum > 0 { penalty += 2 * max(0, (value ?? 0) - maximum) / maximum }
        }
        // Tie-breakers only: protein per 100 kcal, then fewer items. Kept far smaller than any real miss of the goal.
        penalty -= 0.0004 * ((totals.proteinG ?? 0) / max(calories, 1) * 100)
        penalty += 0.001 * Double(max(0, itemCount - 1))
        return penalty
    }

    static func meetsGoal(_ totals: NutrientSet, goal: MacroGoal) -> Bool {
        if let window = goal.calories, !window.contains(totals.calories ?? 0) { return false }
        if let minimum = goal.proteinMin, (totals.proteinG ?? 0) < minimum { return false }
        if let minimum = goal.fiberMin, (totals[.fiber] ?? 0) < minimum { return false }
        if let maximum = goal.carbsMax, (totals.carbsG ?? 0) > maximum { return false }
        if let maximum = goal.fatMax, (totals.fatG ?? 0) > maximum { return false }
        if let maximum = goal.sodiumMax, (totals[.sodium] ?? 0) > maximum { return false }
        return true
    }

    // MARK: Search

    public static func find(
        in restaurant: Restaurant,
        goal: MacroGoal,
        filter: MenuFilter = MenuFilter(),
        structure: Structure = .anyCombination(maxItems: 3),
        limit: Int = 5,
        evaluationBudget: Int = 400_000
    ) -> FitResult {
        var candidates: [Candidate] = []
        var skipped = 0
        for item in restaurant.items where filter.allows(item) {
            let options: [(String?, NutrientSet)] = [(nil, item.nutrients)] + item.variants.map { ($0.id, item.baseNutrients(variantID: $0.id)) }
            // When sizes are published the listed build is just the first size; avoid offering it twice.
            let entries = item.variants.isEmpty ? [options[0]] : Array(options.dropFirst())
            for (variantID, nutrients) in entries {
                guard nutrients.hasCoreMacros else { skipped += 1; continue }
                candidates.append(Candidate(itemID: item.id, variantID: variantID, nutrients: nutrients, section: item.section))
            }
        }
        candidates.sort { ($0.nutrients.calories ?? 0, $0.itemID, $0.variantID ?? "") < ($1.nutrients.calories ?? 0, $1.itemID, $1.variantID ?? "") }

        var best: [(penalty: Double, picks: [Int], totals: NutrientSet)] = []
        var evaluations = 0
        var truncated = false
        let keep = max(limit * 4, 20)
        // Calories only grow as items are added, so a partial order already over the window can be cut off.
        let calorieCeiling = goal.calories.map { $0.upperBound * 1.15 }

        func record(_ picks: [Int], _ totals: NutrientSet) {
            evaluations += 1
            let value = penalty(totals, itemCount: picks.count, goal: goal)
            best.append((value, picks, totals))
            if best.count > keep * 4 {
                best.sort { $0.penalty < $1.penalty }
                best.removeSubrange(keep...)
            }
        }

        func add(_ totals: NutrientSet, _ candidate: Candidate) -> NutrientSet {
            var sum = totals
            for nutrient in candidate.nutrients.nutrients {
                sum[nutrient] = (sum[nutrient] ?? 0) + (candidate.nutrients[nutrient] ?? 0)
            }
            return sum
        }

        switch structure {
        case let .anyCombination(maxItems):
            func search(start: Int, picks: [Int], totals: NutrientSet) {
                guard picks.count < maxItems else { return }
                for index in start..<candidates.count {
                    if evaluations >= evaluationBudget { truncated = true; return }
                    let next = add(totals, candidates[index])
                    if let ceiling = calorieCeiling, (next.calories ?? 0) > ceiling { break }
                    record(picks + [index], next)
                    search(start: index, picks: picks + [index], totals: next)
                    if truncated { return }
                }
            }
            if maxItems > 0 { search(start: 0, picks: [], totals: NutrientSet()) }

        case let .slots(slots):
            let perSlot: [[Int]] = slots.map { sections in
                candidates.indices.filter { sections.contains(candidates[$0].section) }
            }
            func search(slot: Int, picks: [Int], totals: NutrientSet) {
                if slot == perSlot.count {
                    if !picks.isEmpty { record(picks, totals) }
                    return
                }
                search(slot: slot + 1, picks: picks, totals: totals)   // leave this slot empty
                for index in perSlot[slot] {
                    if evaluations >= evaluationBudget { truncated = true; return }
                    let next = add(totals, candidates[index])
                    if let ceiling = calorieCeiling, (next.calories ?? 0) > ceiling { break }
                    search(slot: slot + 1, picks: picks + [index], totals: next)
                    if truncated { return }
                }
            }
            search(slot: 0, picks: [], totals: NutrientSet())
        }

        best.sort { lhs, rhs in
            lhs.penalty != rhs.penalty ? lhs.penalty < rhs.penalty : key(lhs.picks, candidates) < key(rhs.picks, candidates)
        }

        // Identical orders (same multiset of items) collapse to one suggestion.
        var seen: Set<String> = []
        var suggestions: [FitSuggestion] = []
        for entry in best {
            let signature = entry.picks.map { "\(candidates[$0].itemID)#\(candidates[$0].variantID ?? "")" }.sorted().joined(separator: "|")
            guard seen.insert(signature).inserted else { continue }
            let lines = lines(for: entry.picks.map { candidates[$0] })
            let meal = MealBuilder.build(lines, in: restaurant)
            suggestions.append(FitSuggestion(lines: lines, totals: meal.totals, penalty: entry.penalty, meetsGoal: meetsGoal(meal.totals, goal: goal)))
            if suggestions.count == limit { break }
        }
        return FitResult(suggestions: suggestions, itemsConsidered: candidates.count, itemsSkippedForMissingNutrition: skipped, truncated: truncated)
    }

    private static func key(_ picks: [Int], _ candidates: [Candidate]) -> String {
        picks.map { "\(candidates[$0].itemID)#\(candidates[$0].variantID ?? "")" }.sorted().joined(separator: "|")
    }

    /// Repeated picks of one item collapse into a single line with a larger quantity.
    private static func lines(for picks: [Candidate]) -> [OrderLine] {
        var lines: [OrderLine] = []
        for pick in picks {
            if let index = lines.firstIndex(where: { $0.itemID == pick.itemID && $0.variantID == pick.variantID }) {
                lines[index].quantity += 1
            } else {
                lines.append(OrderLine(itemID: pick.itemID, variantID: pick.variantID))
            }
        }
        return lines
    }
}

// MARK: Tweaks

public enum TweakAction: Equatable, Sendable {
    case remove(optionName: String)
    case add(optionName: String)
    case swap(from: String, to: String)
}

public struct TweakSuggestion: Equatable, Sendable {
    public let lineIndex: Int
    public let groupID: String
    public let action: TweakAction
    /// The order with the tweak applied.
    public let lines: [OrderLine]
    public let totals: NutrientSet
    /// How much closer to the goal the tweak gets (positive is better).
    public let improvement: Double
}

/// "Hold the cheese": single option changes that bring an order closer to a goal.
public enum TweakSuggester {
    public static func suggest(for lines: [OrderLine], in restaurant: Restaurant, goal: MacroGoal, limit: Int = 3) -> [TweakSuggestion] {
        let baseline = MealBuilder.build(lines, in: restaurant)
        let baselinePenalty = MacroFitFinder.penalty(baseline.totals, itemCount: lines.count, goal: goal)

        var suggestions: [TweakSuggestion] = []
        for (lineIndex, line) in lines.enumerated() {
            guard let item = restaurant.item(id: line.itemID) else { continue }
            for groupID in item.modifierGroupIDs {
                guard let group = restaurant.group(id: groupID) else { continue }
                let current = line.selections[groupID] ?? group.defaultOptionIDs

                for option in group.options {
                    var changed = line
                    let action: TweakAction
                    if current.contains(option.id) {
                        // Removing is not allowed from a required single-choice group; swapping covers that case.
                        if case .single(required: true) = group.rule { continue }
                        changed.selections[groupID] = current.subtracting([option.id])
                        action = .remove(optionName: option.name)
                    } else if case .single = group.rule {
                        changed.selections[groupID] = [option.id]
                        let from = group.options.first { current.contains($0.id) }?.name
                        action = from.map { .swap(from: $0, to: option.name) } ?? .add(optionName: option.name)
                    } else {
                        if case let .multiple(max) = group.rule, let max, current.count >= max { continue }
                        changed.selections[groupID] = current.union([option.id])
                        action = .add(optionName: option.name)
                    }

                    var tweaked = lines
                    tweaked[lineIndex] = changed
                    let meal = MealBuilder.build(tweaked, in: restaurant)
                    let improvement = baselinePenalty - MacroFitFinder.penalty(meal.totals, itemCount: tweaked.count, goal: goal)
                    if improvement > 0.01 {
                        suggestions.append(TweakSuggestion(lineIndex: lineIndex, groupID: groupID, action: action, lines: tweaked, totals: meal.totals, improvement: improvement))
                    }
                }
            }
        }
        suggestions.sort { $0.improvement != $1.improvement ? $0.improvement > $1.improvement : "\($0.action)" < "\($1.action)" }
        return Array(suggestions.prefix(limit))
    }
}
