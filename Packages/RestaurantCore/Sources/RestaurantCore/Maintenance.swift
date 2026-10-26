import Foundation
import FoodCore

// MARK: Diff

public struct NutrientChange: Equatable, Sendable {
    public let nutrient: Nutrient
    /// Nil when the variant id is the listed build.
    public let variantID: String?
    public let old: Double?
    public let new: Double?
}

public struct ItemChange: Equatable, Sendable {
    public enum Status: Equatable, Sendable { case added, removed, modified }

    public let itemID: String
    public let name: String
    public let status: Status
    public let nutrientChanges: [NutrientChange]
    /// Allergen changes matter more than calorie changes: show them first.
    public let allergensAdded: Set<Allergen>
    public let allergensRemoved: Set<Allergen>
    public let renamedFrom: String?
}

public struct RestaurantChange: Equatable, Sendable {
    public let restaurantID: String
    public let name: String
    public let items: [ItemChange]
}

public struct LibraryChanges: Equatable, Sendable {
    public var addedRestaurants: [String] = []
    public var removedRestaurants: [String] = []
    public var changedRestaurants: [RestaurantChange] = []

    public var isEmpty: Bool { addedRestaurants.isEmpty && removedRestaurants.isEmpty && changedRestaurants.isEmpty }
    public var itemChangeCount: Int { changedRestaurants.reduce(0) { $0 + $1.items.count } }
}

/// What changed between two library versions, for an "updated menus" screen and for flagging stale user overrides.
public enum LibraryDiff {
    /// Smallest change worth reporting for each unit (below this is rounding noise).
    static func threshold(for nutrient: Nutrient) -> Double {
        switch nutrient.unit {
        case .kcal, .mg: return 1
        case .g, .mcg: return 0.1
        }
    }

    public static func diff(old: RestaurantLibrary, new: RestaurantLibrary) -> LibraryChanges {
        var changes = LibraryChanges()
        let oldByID = Dictionary(uniqueKeysWithValues: old.restaurants.map { ($0.id, $0) })
        let newByID = Dictionary(uniqueKeysWithValues: new.restaurants.map { ($0.id, $0) })

        changes.addedRestaurants = new.restaurants.map(\.id).filter { oldByID[$0] == nil }
        changes.removedRestaurants = old.restaurants.map(\.id).filter { newByID[$0] == nil }

        for restaurant in new.restaurants {
            guard let before = oldByID[restaurant.id] else { continue }
            let items = itemChanges(old: before, new: restaurant)
            if !items.isEmpty { changes.changedRestaurants.append(RestaurantChange(restaurantID: restaurant.id, name: restaurant.name, items: items)) }
        }
        return changes
    }

    static func itemChanges(old: Restaurant, new: Restaurant) -> [ItemChange] {
        let oldByID = Dictionary(uniqueKeysWithValues: old.items.map { ($0.id, $0) })
        let newIDs = Set(new.items.map(\.id))
        var result: [ItemChange] = []

        for item in new.items {
            guard let before = oldByID[item.id] else {
                result.append(ItemChange(itemID: item.id, name: item.name, status: .added, nutrientChanges: [], allergensAdded: [], allergensRemoved: [], renamedFrom: nil))
                continue
            }
            var nutrientChanges = compare(before.nutrients, item.nutrients, variantID: nil)
            let variantIDs = Set(before.variants.map(\.id)).union(item.variants.map(\.id)).sorted()
            for id in variantIDs {
                nutrientChanges += compare(
                    before.variants.contains { $0.id == id } ? before.baseNutrients(variantID: id) : NutrientSet(),
                    item.variants.contains { $0.id == id } ? item.baseNutrients(variantID: id) : NutrientSet(),
                    variantID: id
                )
            }
            let added = item.allergens.subtracting(before.allergens)
            let removed = before.allergens.subtracting(item.allergens)
            let renamed = before.name != item.name ? before.name : nil
            if !nutrientChanges.isEmpty || !added.isEmpty || !removed.isEmpty || renamed != nil {
                result.append(ItemChange(itemID: item.id, name: item.name, status: .modified, nutrientChanges: nutrientChanges,
                                         allergensAdded: added, allergensRemoved: removed, renamedFrom: renamed))
            }
        }
        for item in old.items where !newIDs.contains(item.id) {
            result.append(ItemChange(itemID: item.id, name: item.name, status: .removed, nutrientChanges: [], allergensAdded: [], allergensRemoved: [], renamedFrom: nil))
        }
        return result
    }

    private static func compare(_ old: NutrientSet, _ new: NutrientSet, variantID: String?) -> [NutrientChange] {
        var changes: [NutrientChange] = []
        for nutrient in Nutrient.allCases {
            let before = old[nutrient], after = new[nutrient]
            switch (before, after) {
            case (nil, nil): continue
            case let (b?, a?) where abs(a - b) < threshold(for: nutrient): continue
            default: changes.append(NutrientChange(nutrient: nutrient, variantID: variantID, old: before, new: after))
            }
        }
        return changes
    }
}

// MARK: Fingerprint

public enum ItemFingerprint {
    /// A short stable hash of an item's published nutrition (listed build and sizes). Names and allergens are left out
    /// so renaming an item does not invalidate a user's corrections.
    public static func of(_ item: MenuItem) -> String {
        var parts: [String] = [describe(item.nutrients)]
        for variant in item.variants.sorted(by: { $0.id < $1.id }) {
            parts.append("\(variant.id)=\(describe(item.baseNutrients(variantID: variant.id)))")
        }
        return fnv1a(parts.joined(separator: "|"))
    }

    static func describe(_ set: NutrientSet) -> String {
        set.nutrients.map { "\($0.rawValue):\(String(format: "%.2f", set[$0] ?? 0))" }.joined(separator: ",")
    }

    /// FNV-1a 64-bit: stable across launches and platforms, unlike Swift's randomised `Hasher`.
    static func fnv1a(_ text: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}

// MARK: User overlay

public struct ItemOverride: Codable, Equatable, Sendable {
    public var itemID: String
    /// The user's numbers for the listed build.
    public var nutrients: NutrientSet
    /// Fingerprint of the library item when the override was made.
    public var baseFingerprint: String
    public var note: String?
}

public enum OverrideState: Equatable, Sendable {
    case current
    /// The library changed this item after the override was made: ask the user which numbers to keep.
    case baseChanged
    /// The item no longer exists in the library.
    case orphaned
}

public enum OverrideResolution: Equatable, Sendable {
    case keepMine
    case useLibrary
}

/// The user's corrections and additions, kept apart from the shipped library so a library update never loses them.
public struct UserOverlay: Codable, Equatable, Sendable {
    public private(set) var overrides: [String: ItemOverride] = [:]
    /// Items the user added to a chain's menu, by restaurant ID.
    public private(set) var customItems: [String: [MenuItem]] = [:]
    /// Whole restaurants the user created ("Joe's Diner").
    public private(set) var customRestaurants: [Restaurant] = []

    public init() {}

    public mutating func setOverride(for item: MenuItem, nutrients: NutrientSet, note: String? = nil) {
        overrides[item.id] = ItemOverride(itemID: item.id, nutrients: nutrients, baseFingerprint: ItemFingerprint.of(item), note: note)
    }

    public mutating func removeOverride(itemID: String) {
        overrides[itemID] = nil
    }

    public mutating func addCustomItem(_ item: MenuItem, toRestaurant restaurantID: String) {
        var item = item
        item.provenance = item.provenance ?? Provenance(kind: .userContributed, sourceName: "You", license: .userOwned, asOf: "")
        customItems[restaurantID, default: []].removeAll { $0.id == item.id }
        customItems[restaurantID, default: []].append(item)
    }

    public mutating func addCustomRestaurant(_ restaurant: Restaurant) {
        customRestaurants.removeAll { $0.id == restaurant.id }
        customRestaurants.append(restaurant)
    }

    public func state(of override: ItemOverride, in library: RestaurantLibrary) -> OverrideState {
        guard let found = library.item(id: override.itemID) else { return .orphaned }
        return ItemFingerprint.of(found.item) == override.baseFingerprint ? .current : .baseChanged
    }

    public func states(in library: RestaurantLibrary) -> [String: OverrideState] {
        overrides.mapValues { state(of: $0, in: library) }
    }

    /// Settles an override whose base item changed. Keeping the user's numbers re-bases the override on the new item.
    public mutating func resolve(itemID: String, resolution: OverrideResolution, in library: RestaurantLibrary) {
        guard let existing = overrides[itemID] else { return }
        switch resolution {
        case .useLibrary:
            overrides[itemID] = nil
        case .keepMine:
            if let found = library.item(id: itemID) {
                overrides[itemID] = ItemOverride(itemID: itemID, nutrients: existing.nutrients, baseFingerprint: ItemFingerprint.of(found.item), note: existing.note)
            }
        }
    }

    /// The library as the user sees it: corrected numbers on the listed build, plus their own items and restaurants.
    /// Orphaned overrides are ignored. Sizes keep their published numbers.
    public func applied(to library: RestaurantLibrary) -> RestaurantLibrary {
        var restaurants = library.restaurants.map { restaurant -> Restaurant in
            var copy = restaurant
            for index in copy.items.indices {
                if let override = overrides[copy.items[index].id] { copy.items[index].nutrients = override.nutrients }
            }
            copy.items += customItems[restaurant.id] ?? []
            return copy
        }
        restaurants += customRestaurants
        return RestaurantLibrary(version: library.version, restaurants: restaurants)
    }
}

// MARK: Attribution and data-health

public struct AttributionEntry: Equatable, Sendable {
    public let sourceName: String
    public let sourceURL: String?
    public let license: LicenseTag
    public let restaurantCount: Int
    public let itemCount: Int
}

public enum LibraryWarning: Equatable, Sendable {
    /// Fictional demo data is present and must not ship as real.
    case containsDemoData(restaurantID: String)
    /// A share-alike license applies to a source; redistributing a derived database has obligations.
    case shareAlikeSource(sourceName: String)
    case unknownLicense(restaurantID: String)
    case staleMenu(restaurantID: String, asOf: String)
}

public enum LibraryAttribution {
    /// The "Data sources" screen: one entry per source and license, with how much of the library comes from it.
    public static func credits(for library: RestaurantLibrary) -> [AttributionEntry] {
        struct Key: Hashable { let name: String; let license: LicenseTag; let url: String? }
        var counts: [Key: (restaurants: Set<String>, items: Int)] = [:]
        for restaurant in library.restaurants {
            for item in restaurant.items {
                let provenance = restaurant.effectiveProvenance(for: item)
                let key = Key(name: provenance.sourceName, license: provenance.license, url: provenance.sourceURL)
                var entry = counts[key] ?? (Set<String>(), 0)
                entry.restaurants.insert(restaurant.id)
                entry.items += 1
                counts[key] = entry
            }
        }
        return counts.map { AttributionEntry(sourceName: $0.key.name, sourceURL: $0.key.url, license: $0.key.license, restaurantCount: $0.value.restaurants.count, itemCount: $0.value.items) }
            .sorted { ($0.itemCount, $1.sourceName) > ($1.itemCount, $0.sourceName) }
    }

    /// Release-blocking problems with a library. `now` is passed in so tests are deterministic.
    public static func warnings(for library: RestaurantLibrary, now: Date = Date(), staleAfterMonths: Int = 12) -> [LibraryWarning] {
        var warnings: [LibraryWarning] = []
        var seenShareAlike: Set<String> = []
        for restaurant in library.restaurants {
            let provenances = [restaurant.provenance] + restaurant.items.compactMap(\.provenance)
            if provenances.contains(where: \.isDemo) { warnings.append(.containsDemoData(restaurantID: restaurant.id)) }
            if provenances.contains(where: { $0.license == .unknown }) { warnings.append(.unknownLicense(restaurantID: restaurant.id)) }
            for provenance in provenances where provenance.license.isShareAlike && seenShareAlike.insert(provenance.sourceName).inserted {
                warnings.append(.shareAlikeSource(sourceName: provenance.sourceName))
            }
            if let months = monthsSince(restaurant.provenance.asOf, now: now), months > staleAfterMonths {
                warnings.append(.staleMenu(restaurantID: restaurant.id, asOf: restaurant.provenance.asOf))
            }
        }
        return warnings
    }

    /// Whole months between a "YYYY-MM" or "YYYY-MM-DD" date and `now` (UTC); nil when the text is not a date.
    static func monthsSince(_ asOf: String, now: Date) -> Int? {
        let parts = asOf.split(separator: "-")
        guard parts.count >= 2, let year = Int(parts[0]), let month = Int(parts[1]), (1...12).contains(month) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let current = calendar.dateComponents([.year, .month], from: now)
        guard let currentYear = current.year, let currentMonth = current.month else { return nil }
        return (currentYear - year) * 12 + (currentMonth - month)
    }
}
