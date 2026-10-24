import Foundation

public enum FoodSource: String, Codable, Sendable, CaseIterable, Hashable {
    case userCreated
    case labelScan
    case usdaBranded
    case openFoodFacts
    case restaurantLibrary
    case other

    /// Starting trust used when ranking and merging, before consistency checks adjust it. These are judgement calls
    /// kept in one place so they can be tuned: a user's own entry is authoritative for that user; USDA branded data
    /// is manufacturer-submitted; Open Food Facts is crowd-sourced and so is trusted a little less.
    public var trustPrior: Double {
        switch self {
        case .userCreated: return 1.0
        case .usdaBranded: return 0.9
        case .labelScan, .restaurantLibrary: return 0.85
        case .openFoodFacts: return 0.75
        case .other: return 0.5
        }
    }
}

public enum DataQualityFlag: Hashable, Sendable, Codable {
    case missingName
    case missingEnergy
    case missingMacros
    /// Declared calories differ from 4P + 4C + 9F (+7 alcohol) by more than label rounding explains.
    case energyMismatch(declaredKcal: Double, atwaterKcal: Double)
    /// Protein + carbohydrate + fat exceed the mass the nutrients are quoted over.
    case macrosExceedMass(grams: Double)
    case implausibleEnergyDensity(kcalPer100: Double)
    case negativeValue(Nutrient)
    /// A part larger than the whole, e.g. sugars above carbohydrate.
    case componentExceedsTotal(part: Nutrient, total: Nutrient)
    case noServingSize
    /// Only per-serving values exist, so portions other than whole servings cannot be scaled reliably.
    case servingOnlyBasis
    /// Two sources disagree materially about this nutrient.
    case sourcesDisagree(Nutrient)
}

public struct FoodRecord: Equatable, Sendable, Codable {
    public var id: String
    public var gtin: GTIN?
    public var name: String
    public var brand: String?
    public var source: FoodSource
    public var per100g: NutrientSet?
    public var per100ml: NutrientSet?
    public var perServing: NutrientSet?
    public var serving: ServingSize?
    public var packageSize: ServingSize?
    public var ingredients: String?
    public var allergens: Set<Allergen>
    public var traces: Set<Allergen>
    /// Which source supplied each nutrient after merging (keyed by `Nutrient.rawValue`).
    public var fieldSources: [String: FoodSource]
    public var fetchedAt: Date?
    public var flags: [DataQualityFlag]

    public init(
        id: String,
        gtin: GTIN? = nil,
        name: String,
        brand: String? = nil,
        source: FoodSource,
        per100g: NutrientSet? = nil,
        per100ml: NutrientSet? = nil,
        perServing: NutrientSet? = nil,
        serving: ServingSize? = nil,
        packageSize: ServingSize? = nil,
        ingredients: String? = nil,
        allergens: Set<Allergen> = [],
        traces: Set<Allergen> = [],
        fieldSources: [String: FoodSource] = [:],
        fetchedAt: Date? = nil,
        flags: [DataQualityFlag] = []
    ) {
        self.id = id
        self.gtin = gtin
        self.name = name
        self.brand = brand
        self.source = source
        self.per100g = per100g
        self.per100ml = per100ml
        self.perServing = perServing
        self.serving = serving
        self.packageSize = packageSize
        self.ingredients = ingredients
        self.allergens = allergens
        self.traces = traces
        self.fieldSources = fieldSources
        self.fetchedAt = fetchedAt
        self.flags = flags
    }

    /// Display name with brand, e.g. "Sunny Oat Crunch - Fictional Foods Co."
    public var displayName: String {
        guard let brand, !brand.isEmpty, !name.localizedCaseInsensitiveContains(brand) else { return name }
        return "\(name) - \(brand)"
    }

    public var hasUsableNutrition: Bool {
        [per100g, per100ml, perServing].contains { $0?.hasCoreMacros == true }
    }

    // MARK: Portions

    /// Nutrients for a portion, scaling from whichever basis the record can support. Nil when the record lacks the
    /// information (e.g. grams requested but no per-100 g or gram serving weight exists).
    public func nutrients(for portion: Portion) -> NutrientSet? {
        switch portion {
        case let .servings(count):
            guard count >= 0 else { return nil }
            if let perServing { return perServing.scaled(by: count) }
            if let grams = serving?.grams, let per100g { return per100g.scaled(by: grams * count / 100) }
            if let milliliters = serving?.milliliters, let per100ml { return per100ml.scaled(by: milliliters * count / 100) }
            return nil
        case let .grams(grams):
            guard grams >= 0 else { return nil }
            if let per100g { return per100g.scaled(by: grams / 100) }
            if let perServing, let servingGrams = serving?.grams, servingGrams > 0 { return perServing.scaled(by: grams / servingGrams) }
            return nil
        case let .milliliters(milliliters):
            guard milliliters >= 0 else { return nil }
            if let per100ml { return per100ml.scaled(by: milliliters / 100) }
            if let perServing, let servingML = serving?.milliliters, servingML > 0 { return perServing.scaled(by: milliliters / servingML) }
            return nil
        case let .packages(count):
            guard count >= 0 else { return nil }
            if let grams = packageSize?.grams, let result = nutrients(for: .grams(grams * count)) { return result }
            if let milliliters = packageSize?.milliliters, let result = nutrients(for: .milliliters(milliliters * count)) { return result }
            return nil
        }
    }
}

/// How much of a food was eaten.
public enum Portion: Equatable, Sendable {
    case servings(Double)
    case grams(Double)
    case milliliters(Double)
    /// Fractions of the whole package ("half the bag" is 0.5).
    case packages(Double)
}

public enum MappingOutcome: Equatable, Sendable {
    case found(FoodRecord)
    case notFound
    /// The response could not be understood at all (not JSON, wrong shape).
    case malformed(String)
}
