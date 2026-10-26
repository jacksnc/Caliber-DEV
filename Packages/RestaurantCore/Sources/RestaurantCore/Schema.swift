import Foundation
import FoodCore

public enum RestaurantCategory: String, Codable, Sendable, CaseIterable {
    case burgers, pizza, sandwiches, chicken, mexican, asian, italian, coffee, bakery, dessert, breakfast, salads, seafood, american, other
}

/// Diet claims as published by the restaurant. They are claims, never guarantees, and the UI must say so.
public enum DietTag: String, Codable, Sendable, CaseIterable {
    case vegetarian, vegan, glutenFree, dairyFree, nutFree
}

public enum ProvenanceKind: String, Codable, Sendable {
    /// Published by the restaurant itself (nutrition PDF, website, in-store poster).
    case officialChain
    case governmentDataset
    case licensedAPI
    case userContributed
    /// Computed from components with the dish estimator.
    case estimated
    /// Invented for demos and tests; must never be presented as real restaurant data.
    case demoFictional
}

/// Terms under which a dataset may ship inside the app. `unknown` means "do not bundle".
public enum LicenseTag: String, Codable, Sendable {
    case publicDomain, cc0
    case ccBy, ccBySa, odbl
    /// Written permission from the data owner.
    case permissionGranted
    case licensedCommercial
    /// Entered by the user for their own use.
    case userOwned
    case unknown

    public var allowsBundling: Bool { self != .unknown }

    public var requiresAttribution: Bool {
        switch self {
        case .ccBy, .ccBySa, .odbl, .permissionGranted, .licensedCommercial: return true
        default: return false
        }
    }

    /// Share-alike licenses constrain how a derived database may be redistributed.
    public var isShareAlike: Bool { self == .ccBySa || self == .odbl }

    public init(parsing text: String) {
        let key = text.lowercased().filter { $0.isLetter || $0.isNumber }
        switch key {
        case "publicdomain", "pd", "usgov", "usgovernment": self = .publicDomain
        case "cc0": self = .cc0
        case "ccby", "ccby40": self = .ccBy
        case "ccbysa", "ccbysa40": self = .ccBySa
        case "odbl": self = .odbl
        case "permission", "permissiongranted": self = .permissionGranted
        case "licensed", "commercial", "licensedcommercial": self = .licensedCommercial
        case "user", "userowned", "own": self = .userOwned
        default: self = .unknown
        }
    }
}

public struct Provenance: Codable, Equatable, Sendable {
    public var kind: ProvenanceKind
    public var sourceName: String
    public var sourceURL: String?
    public var license: LicenseTag
    /// Date the numbers were current: "2026-09" or "2026-09-14".
    public var asOf: String

    public init(kind: ProvenanceKind, sourceName: String, sourceURL: String? = nil, license: LicenseTag, asOf: String) {
        self.kind = kind
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.license = license
        self.asOf = asOf
    }

    public var isDemo: Bool { kind == .demoFictional }
}

public struct ModifierOption: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// What this option contributes to a build that includes it. Deltas of default options are subtracted when the
    /// option is removed ("no cheese").
    public var delta: NutrientSet
    /// True when the listed nutrition already includes this option.
    public var isDefault: Bool
    public var aliases: [String]

    public init(id: String, name: String, delta: NutrientSet, isDefault: Bool = false, aliases: [String] = []) {
        self.id = id
        self.name = name
        self.delta = delta
        self.isDefault = isDefault
        self.aliases = aliases
    }
}

public enum SelectionRule: Codable, Equatable, Sendable {
    /// Pick at most one; `required` means exactly one.
    case single(required: Bool)
    /// Pick any number, optionally capped.
    case multiple(max: Int?)
}

public struct ModifierGroup: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var rule: SelectionRule
    public var options: [ModifierOption]

    public init(id: String, name: String, rule: SelectionRule, options: [ModifierOption]) {
        self.id = id
        self.name = name
        self.rule = rule
        self.options = options
    }

    public var defaultOptionIDs: Set<String> { Set(options.filter(\.isDefault).map(\.id)) }
}

/// A size or flavour of an item with its own published nutrition ("Large"), or a multiple of the base ("1.5x").
public struct ItemVariant: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var nutrients: NutrientSet?
    public var scale: Double?

    public init(id: String, name: String, nutrients: NutrientSet? = nil, scale: Double? = nil) {
        self.id = id
        self.name = name
        self.nutrients = nutrients
        self.scale = scale
    }
}

public struct MenuItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var section: String
    public var aliases: [String]
    public var description: String?
    /// "1 burger", "12 fl oz".
    public var servingDescription: String?
    public var servingGrams: Double?
    /// Nutrition of the listed build, including every default modifier option.
    public var nutrients: NutrientSet
    public var variants: [ItemVariant]
    public var modifierGroupIDs: [String]
    public var allergens: Set<Allergen>
    public var dietTags: Set<DietTag>
    /// Overrides the restaurant-level provenance when an item came from a different source.
    public var provenance: Provenance?

    public init(
        id: String,
        name: String,
        section: String,
        aliases: [String] = [],
        description: String? = nil,
        servingDescription: String? = nil,
        servingGrams: Double? = nil,
        nutrients: NutrientSet,
        variants: [ItemVariant] = [],
        modifierGroupIDs: [String] = [],
        allergens: Set<Allergen> = [],
        dietTags: Set<DietTag> = [],
        provenance: Provenance? = nil
    ) {
        self.id = id
        self.name = name
        self.section = section
        self.aliases = aliases
        self.description = description
        self.servingDescription = servingDescription
        self.servingGrams = servingGrams
        self.nutrients = nutrients
        self.variants = variants
        self.modifierGroupIDs = modifierGroupIDs
        self.allergens = allergens
        self.dietTags = dietTags
        self.provenance = provenance
    }

    /// Nutrition of one serving of the chosen variant (the listed build when `variantID` is nil or unknown).
    public func baseNutrients(variantID: String?) -> NutrientSet {
        guard let variantID, let variant = variants.first(where: { $0.id == variantID }) else { return nutrients }
        if let own = variant.nutrients { return own }
        if let scale = variant.scale { return nutrients.scaled(by: scale) }
        return nutrients
    }
}

public struct Restaurant: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var aliases: [String]
    public var category: RestaurantCategory
    /// ISO 3166-1 alpha-2 region the menu applies to, e.g. "US".
    public var region: String?
    public var provenance: Provenance
    public var items: [MenuItem]
    public var modifierGroups: [ModifierGroup]

    public init(
        id: String,
        name: String,
        aliases: [String] = [],
        category: RestaurantCategory = .other,
        region: String? = nil,
        provenance: Provenance,
        items: [MenuItem] = [],
        modifierGroups: [ModifierGroup] = []
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.category = category
        self.region = region
        self.provenance = provenance
        self.items = items
        self.modifierGroups = modifierGroups
    }

    /// Sections in the order they first appear on the menu.
    public var sections: [String] {
        var seen: [String] = []
        for item in items where !seen.contains(item.section) { seen.append(item.section) }
        return seen
    }

    public func item(id: String) -> MenuItem? { items.first { $0.id == id } }
    public func group(id: String) -> ModifierGroup? { modifierGroups.first { $0.id == id } }

    public func effectiveProvenance(for item: MenuItem) -> Provenance { item.provenance ?? provenance }
}

public struct RestaurantLibrary: Codable, Equatable, Sendable {
    public var version: String
    public var restaurants: [Restaurant]

    public init(version: String, restaurants: [Restaurant]) {
        self.version = version
        self.restaurants = restaurants
    }

    public var itemCount: Int { restaurants.reduce(0) { $0 + $1.items.count } }

    public func restaurant(id: String) -> Restaurant? { restaurants.first { $0.id == id } }

    public func item(id: String) -> (restaurant: Restaurant, item: MenuItem)? {
        for restaurant in restaurants {
            if let item = restaurant.item(id: id) { return (restaurant, item) }
        }
        return nil
    }
}

public enum Slug {
    /// Lower-case ASCII identifier: "Crème Brûlée & Fries!" becomes "creme-brulee-and-fries".
    public static func make(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")
        var result = ""
        var lastWasSeparator = true
        for character in folded.lowercased() {
            if character.isASCII, character.isLetter || character.isNumber {
                result.append(character)
                lastWasSeparator = false
            } else if !lastWasSeparator {
                result.append("-")
                lastWasSeparator = true
            }
        }
        if result.hasSuffix("-") { result.removeLast() }
        return result
    }
}
