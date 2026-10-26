import Foundation

public enum NutrientUnit: String, Codable, Sendable {
    case kcal, g, mg, mcg

    /// Multiplier that converts a value in `self` to grams (kcal has no mass equivalent).
    var gramsPerUnit: Double? {
        switch self {
        case .g: return 1
        case .mg: return 1e-3
        case .mcg: return 1e-6
        case .kcal: return nil
        }
    }
}

/// Canonical nutrients tracked across barcode, label and restaurant data. Each has one canonical unit.
public enum Nutrient: String, Codable, Sendable, CaseIterable, Hashable {
    case energyKcal
    case protein, carbohydrate, fat
    case saturatedFat, transFat, monounsaturatedFat, polyunsaturatedFat
    case cholesterol, sodium
    case fiber, sugars, addedSugars, sugarAlcohols
    case potassium, calcium, iron, magnesium, zinc
    case vitaminD, vitaminC
    case caffeine, alcohol

    public var unit: NutrientUnit {
        switch self {
        case .energyKcal: return .kcal
        case .protein, .carbohydrate, .fat, .saturatedFat, .transFat, .monounsaturatedFat, .polyunsaturatedFat,
             .fiber, .sugars, .addedSugars, .sugarAlcohols, .alcohol:
            return .g
        case .cholesterol, .sodium, .potassium, .calcium, .iron, .magnesium, .zinc, .vitaminC, .caffeine:
            return .mg
        case .vitaminD:
            return .mcg
        }
    }

    /// Macronutrients that drive the energy cross-check.
    public static let macros: [Nutrient] = [.protein, .carbohydrate, .fat]
}

/// Nutrient amounts in canonical units, over one stated basis (per 100 g, per serving, ...). Missing means unknown, not zero.
public struct NutrientSet: Equatable, Sendable, Codable {
    public private(set) var values: [Nutrient: Double]

    public init(_ values: [Nutrient: Double] = [:]) {
        self.values = values
    }

    public subscript(nutrient: Nutrient) -> Double? {
        get { values[nutrient] }
        set { values[nutrient] = newValue }
    }

    public var isEmpty: Bool { values.isEmpty }
    public var nutrients: [Nutrient] { values.keys.sorted { $0.rawValue < $1.rawValue } }

    public var calories: Double? { values[.energyKcal] }
    public var proteinG: Double? { values[.protein] }
    public var carbsG: Double? { values[.carbohydrate] }
    public var fatG: Double? { values[.fat] }

    /// True when energy and all three macros are present: enough to log the food.
    public var hasCoreMacros: Bool {
        values[.energyKcal] != nil && Nutrient.macros.allSatisfy { values[$0] != nil }
    }

    /// Atwater general factors: 4 kcal/g protein and carbohydrate, 9 kcal/g fat, 7 kcal/g alcohol.
    /// A plausibility check on declared energy, never a replacement for it.
    public var atwaterKcal: Double? {
        guard let p = values[.protein], let c = values[.carbohydrate], let f = values[.fat] else { return nil }
        return 4 * p + 4 * c + 9 * f + 7 * (values[.alcohol] ?? 0)
    }

    public func scaled(by factor: Double) -> NutrientSet {
        NutrientSet(values.mapValues { NutrientSet.clean($0 * factor) })
    }

    /// Per-nutrient sum. A nutrient missing on either side stays missing unless `treatMissingAsZero` is set.
    public func adding(_ other: NutrientSet, treatMissingAsZero: Bool = false) -> NutrientSet {
        var result: [Nutrient: Double] = [:]
        let keys = treatMissingAsZero ? Set(values.keys).union(other.values.keys) : Set(values.keys).intersection(other.values.keys)
        for key in keys {
            result[key] = NutrientSet.clean((values[key] ?? 0) + (other.values[key] ?? 0))
        }
        return NutrientSet(result)
    }

    /// Removes floating-point noise (e.g. 2.4999999999999996 -> 2.5) without hiding real precision.
    public static func clean(_ value: Double) -> Double {
        (value * 1e6).rounded() / 1e6
    }

    // Codable via string keys so JSON stays a plain object on every platform.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode([String: Double].self)
        var parsed: [Nutrient: Double] = [:]
        for (key, value) in raw {
            if let nutrient = Nutrient(rawValue: key) { parsed[nutrient] = value }
        }
        values = parsed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        var raw: [String: Double] = [:]
        for (nutrient, value) in values { raw[nutrient.rawValue] = value }
        try container.encode(raw)
    }
}

public enum Allergen: String, Codable, Sendable, CaseIterable, Hashable {
    case milk, egg, fish, crustaceanShellfish, mollusc
    case treeNut, peanut, wheat, gluten, soy, sesame
    case celery, mustard, lupin, sulphite
}

/// Reference values for judging whether a nutrient amount is plausible.
enum NutritionReference {
    static let kcalPerKilojoule = 1.0 / 4.184
    static let kilojoulesPerKcal = 4.184
    /// Sodium is 39.3% of table salt by mass.
    static let saltToSodium = 1.0 / 2.5
    /// Vitamin D: 40 IU = 1 mcg.
    static let iuPerMcgVitaminD = 40.0
}
