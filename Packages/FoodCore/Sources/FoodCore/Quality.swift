import Foundation

/// Consistency checks that catch the usual crowd-sourced and OCR mistakes before a food reaches the diary.
public enum NutritionValidator {
    /// Relative and absolute slack for the energy cross-check. Labels round, and fiber and sugar alcohols carry
    /// less than 4 kcal/g, so the check is deliberately lenient: it exists to catch kJ-as-kcal and typo errors.
    static let energyRelativeTolerance = 0.25
    static let energyAbsoluteTolerance = 25.0

    public static func validate(_ record: FoodRecord) -> [DataQualityFlag] {
        var flags: [DataQualityFlag] = []
        func add(_ flag: DataQualityFlag) { if !flags.contains(flag) { flags.append(flag) } }

        if record.name.trimmingCharacters(in: .whitespaces).isEmpty { add(.missingName) }

        let bases: [(NutrientSet?, Bool)] = [(record.per100g, true), (record.per100ml, true), (record.perServing, false)]
        var anyEnergy = false
        var anyMacros = false
        for (set, isPer100) in bases {
            guard let set else { continue }
            if set.calories != nil { anyEnergy = true }
            if set.hasCoreMacros { anyMacros = true }
            for check in validate(set, isPer100: isPer100) { add(check) }
        }
        if !anyEnergy { add(.missingEnergy) }
        if !anyMacros { add(.missingMacros) }
        if record.per100g == nil && record.per100ml == nil && record.perServing != nil { add(.servingOnlyBasis) }
        if record.perServing == nil && record.serving == nil { add(.noServingSize) }
        return flags
    }

    static func validate(_ set: NutrientSet, isPer100: Bool) -> [DataQualityFlag] {
        var flags: [DataQualityFlag] = []
        for nutrient in set.nutrients {
            if let value = set[nutrient], value < 0 { flags.append(.negativeValue(nutrient)) }
        }

        if isPer100 {
            let mass = (set.proteinG ?? 0) + (set.carbsG ?? 0) + (set.fatG ?? 0)
            if mass > 100.5 { flags.append(.macrosExceedMass(grams: mass)) }
            if let kcal = set.calories, kcal > 920 { flags.append(.implausibleEnergyDensity(kcalPer100: kcal)) }
        }

        if let declared = set.calories, let computed = set.atwaterKcal {
            let difference = abs(declared - computed)
            let allowed = max(energyAbsoluteTolerance, energyRelativeTolerance * max(declared, computed))
            if difference > allowed { flags.append(.energyMismatch(declaredKcal: declared, atwaterKcal: computed)) }
        }

        let parts: [(Nutrient, Nutrient)] = [
            (.sugars, .carbohydrate), (.fiber, .carbohydrate), (.addedSugars, .sugars), (.saturatedFat, .fat),
        ]
        for (part, total) in parts {
            if let partValue = set[part], let totalValue = set[total], partValue > totalValue + 0.5 {
                flags.append(.componentExceedsTotal(part: part, total: total))
            }
        }
        if let saturated = set[.saturatedFat], let trans = set[.transFat], let fat = set[.fat], saturated + trans > fat + 0.5 {
            flags.append(.componentExceedsTotal(part: .transFat, total: .fat))
        }
        return flags
    }
}

/// Heuristic 0-1 score used to choose between sources and to decide when an early answer is "good enough".
/// The weights are judgement calls (documented here so they can be tuned), not measured quantities.
public enum FoodQuality {
    /// Share of the fields that matter for logging a food that are present.
    public static func completeness(_ record: FoodRecord) -> Double {
        let best = [record.per100g, record.per100ml, record.perServing]
            .compactMap { $0 }
            .max { filled($0) < filled($1) }
        var score = 0.0
        if let best {
            if best.calories != nil { score += 0.30 }
            if best.proteinG != nil { score += 0.15 }
            if best.carbsG != nil { score += 0.15 }
            if best.fatG != nil { score += 0.15 }
        }
        if record.serving != nil || record.perServing != nil { score += 0.10 }
        if !record.name.trimmingCharacters(in: .whitespaces).isEmpty { score += 0.05 }
        if let brand = record.brand, !brand.isEmpty { score += 0.05 }
        if let ingredients = record.ingredients, !ingredients.isEmpty { score += 0.05 }
        return min(score, 1)
    }

    private static func filled(_ set: NutrientSet) -> Int {
        [Nutrient.energyKcal, .protein, .carbohydrate, .fat].filter { set[$0] != nil }.count
    }

    /// Source trust x completeness, reduced by consistency problems.
    public static func score(_ record: FoodRecord) -> Double {
        let major = record.flags.filter { flag in
            switch flag {
            case .energyMismatch, .macrosExceedMass, .implausibleEnergyDensity, .negativeValue, .componentExceedsTotal, .sourcesDisagree:
                return true
            default:
                return false
            }
        }.count
        let consistency = max(0.2, 1 - 0.25 * Double(major))
        return record.source.trustPrior * completeness(record) * consistency
    }
}

/// Combines records for the same GTIN from different sources without ever mixing nutrient bases.
public enum FoodMerger {
    /// Relative disagreement above which two sources are reported as conflicting.
    static let conflictTolerance = 0.15

    public static func merge(_ records: [FoodRecord]) -> FoodRecord? {
        let ranked = records.sorted { FoodQuality.score($0) > FoodQuality.score($1) }
        guard var merged = ranked.first else { return nil }

        func stamp(_ set: NutrientSet?, source: FoodSource) {
            for nutrient in set?.nutrients ?? [] where merged.fieldSources[nutrient.rawValue] == nil {
                merged.fieldSources[nutrient.rawValue] = source
            }
        }
        stamp(merged.per100g, source: merged.source)
        stamp(merged.per100ml, source: merged.source)
        stamp(merged.perServing, source: merged.source)

        for other in ranked.dropFirst() {
            merged.per100g = fill(merged.per100g, from: other.per100g, otherSource: other.source, into: &merged)
            merged.per100ml = fill(merged.per100ml, from: other.per100ml, otherSource: other.source, into: &merged)

            // A per-serving block is only borrowed together with its serving size, so the two stay consistent.
            if merged.perServing == nil, let borrowed = other.perServing {
                merged.perServing = borrowed
                if merged.serving == nil { merged.serving = other.serving }
                stamp(borrowed, source: other.source)
            }
            if merged.serving == nil { merged.serving = other.serving }
            if merged.packageSize == nil { merged.packageSize = other.packageSize }
            if merged.gtin == nil { merged.gtin = other.gtin }
            if (merged.brand ?? "").isEmpty { merged.brand = other.brand }
            if (merged.ingredients ?? "").isEmpty { merged.ingredients = other.ingredients }
            if merged.name.trimmingCharacters(in: .whitespaces).isEmpty { merged.name = other.name }

            // Safety first: an allergen reported by any source is kept.
            merged.allergens.formUnion(other.allergens)
            merged.traces.formUnion(other.traces)
        }

        merged.flags = NutritionValidator.validate(merged)
        for other in ranked.dropFirst() {
            for flag in conflicts(merged, other) where !merged.flags.contains(flag) { merged.flags.append(flag) }
        }
        return merged
    }

    private static func fill(_ base: NutrientSet?, from other: NutrientSet?, otherSource: FoodSource, into record: inout FoodRecord) -> NutrientSet? {
        guard let other else { return base }
        guard var result = base else {
            for nutrient in other.nutrients where record.fieldSources[nutrient.rawValue] == nil {
                record.fieldSources[nutrient.rawValue] = otherSource
            }
            return other
        }
        for nutrient in other.nutrients where result[nutrient] == nil {
            result[nutrient] = other[nutrient]
            record.fieldSources[nutrient.rawValue] = otherSource
        }
        return result
    }

    private static func conflicts(_ a: FoodRecord, _ b: FoodRecord) -> [DataQualityFlag] {
        var flags: [DataQualityFlag] = []
        for (left, right) in [(a.per100g, b.per100g), (a.per100ml, b.per100ml)] {
            guard let left, let right else { continue }
            for nutrient in [Nutrient.energyKcal, .protein, .carbohydrate, .fat] {
                guard let x = left[nutrient], let y = right[nutrient] else { continue }
                let larger = max(abs(x), abs(y))
                // Tiny absolute differences on small values (0.3 g vs 0.5 g) are rounding, not disagreement.
                let slack = nutrient == .energyKcal ? 10.0 : 1.0
                if abs(x - y) > slack, abs(x - y) / larger > conflictTolerance {
                    flags.append(.sourcesDisagree(nutrient))
                }
            }
        }
        return flags
    }
}
