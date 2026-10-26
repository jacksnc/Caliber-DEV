import Foundation
import FoodCore

public struct ImportPolicy: Sendable {
    /// Refuse rows whose license is missing or unrecognised. This is what stops scraped data of unknown origin
    /// from slipping into a bundled library.
    public var requireKnownLicense = true
    /// Used for rows that carry no source columns of their own.
    public var defaultProvenance: Provenance?
    public var defaultRegion: String?
    public var energyRelativeTolerance = 0.25
    public var energyAbsoluteTolerance = 25.0

    public init() {}
}

public struct ImportIssue: Equatable, Sendable {
    public enum Severity: String, Sendable { case error, warning, info }

    public enum Code: String, Sendable {
        case missingColumn, unknownColumn, rowShape, missingValue, invalidNumber, negativeValue
        case duplicateItem, duplicateOption
        case licenseUnknown, provenanceConflict, unknownAllergen, unknownDietTag, unknownModifierGroup
        case energyMismatch, implausibleSodium, implausibleCalories, partsExceedWhole, macrosExceedServing, lessThanValue
    }

    public let severity: Severity
    public let code: Code
    /// 1-based row number in the file; the header is row 1. Nil for file-level problems.
    public let row: Int?
    public let message: String
}

public struct ImportReport: Sendable {
    public var restaurants: [Restaurant] = []
    public var issues: [ImportIssue] = []
    public var rowsRead = 0
    public var rowsImported = 0

    public var hasErrors: Bool { issues.contains { $0.severity == .error } }

    public func issues(_ code: ImportIssue.Code) -> [ImportIssue] { issues.filter { $0.code == code } }
    public func count(_ severity: ImportIssue.Severity) -> Int { issues.filter { $0.severity == severity }.count }
}

public enum LibraryImporter {
    // MARK: Column vocabulary

    private static let textColumns: [String: [String]] = [
        "restaurant": ["restaurant", "chain", "restaurant_name", "brand"],
        "item": ["item", "item_name", "name", "menu_item", "product"],
        "section": ["section", "menu_section", "category", "menu_category"],
        "variant": ["variant", "size", "portion"],
        "serving": ["serving", "serving_size", "serving_description"],
        "serving_g": ["serving_g", "serving_grams", "serving_weight_g", "weight_g"],
        "allergens": ["allergens", "contains"],
        "diet": ["diet_tags", "diet", "dietary"],
        "aliases": ["aliases", "also_known_as", "akas"],
        "description": ["description"],
        "groups": ["modifier_groups", "modifiers", "customizations"],
        "restaurant_category": ["restaurant_category", "cuisine", "chain_category"],
        "region": ["region", "country"],
        "source_kind": ["source_kind", "kind"],
        "source_name": ["source_name", "source"],
        "source_url": ["source_url", "url"],
        "license": ["license", "licence"],
        "as_of": ["as_of", "menu_date", "date", "updated"],
        // modifier file
        "group": ["group", "group_name", "modifier_group"],
        "option": ["option", "option_name", "modifier"],
        "rule": ["rule", "selection", "selection_rule"],
        "default": ["default", "is_default", "included"],
    ]

    private static let nutrientColumns: [(Nutrient, [String])] = [
        (.energyKcal, ["calories", "kcal", "energy_kcal", "cal"]),
        (.protein, ["protein_g", "protein"]),
        (.carbohydrate, ["carbs_g", "carbohydrates_g", "carbs", "carbohydrates", "total_carbohydrate_g", "total_carbs_g"]),
        (.fat, ["fat_g", "total_fat_g", "fat"]),
        (.saturatedFat, ["sat_fat_g", "saturated_fat_g", "saturated_fat"]),
        (.transFat, ["trans_fat_g", "trans_fat"]),
        (.fiber, ["fiber_g", "fibre_g", "dietary_fiber_g", "fiber"]),
        (.sugars, ["sugars_g", "total_sugars_g", "sugar_g", "sugars", "sugar"]),
        (.addedSugars, ["added_sugars_g", "added_sugar_g"]),
        (.sodium, ["sodium_mg", "sodium"]),
        (.cholesterol, ["cholesterol_mg", "cholesterol"]),
        (.potassium, ["potassium_mg"]),
        (.calcium, ["calcium_mg"]),
        (.iron, ["iron_mg"]),
        (.caffeine, ["caffeine_mg"]),
        (.alcohol, ["alcohol_g"]),
    ]

    private static let allergenNames: [String: Allergen] = [
        "milk": .milk, "dairy": .milk, "egg": .egg, "eggs": .egg, "fish": .fish,
        "shellfish": .crustaceanShellfish, "crustacean": .crustaceanShellfish, "crustaceans": .crustaceanShellfish,
        "mollusc": .mollusc, "molluscs": .mollusc, "mollusk": .mollusc, "mollusks": .mollusc,
        "treenut": .treeNut, "treenuts": .treeNut, "nuts": .treeNut, "nut": .treeNut,
        "peanut": .peanut, "peanuts": .peanut, "wheat": .wheat, "gluten": .gluten,
        "soy": .soy, "soya": .soy, "soybean": .soy, "soybeans": .soy, "sesame": .sesame,
        "celery": .celery, "mustard": .mustard, "lupin": .lupin, "sulphite": .sulphite, "sulphites": .sulphite,
        "sulfite": .sulphite, "sulfites": .sulphite,
    ]

    private static let dietNames: [String: DietTag] = [
        "vegetarian": .vegetarian, "vegan": .vegan, "glutenfree": .glutenFree, "gf": .glutenFree,
        "dairyfree": .dairyFree, "nutfree": .nutFree,
    ]

    static func normalizeHeader(_ header: String) -> String {
        var result = ""
        var lastUnderscore = true
        for character in header.lowercased() {
            if character.isLetter || character.isNumber {
                result.append(character)
                lastUnderscore = false
            } else if !lastUnderscore {
                result.append("_")
                lastUnderscore = true
            }
        }
        while result.hasSuffix("_") { result.removeLast() }
        return result
    }

    // MARK: Number parsing

    enum NumberParse: Equatable {
        case missing
        case value(Double)
        case lessThan(Double)
        case invalid
    }

    static func parseNumber(_ raw: String) -> NumberParse {
        var text = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if text.isEmpty || ["-", "--", "\u{2014}", "n/a", "na", "null", "none"].contains(text) { return .missing }
        var lessThan = false
        if text.hasPrefix("<") {
            lessThan = true
            text.removeFirst()
            text = text.trimmingCharacters(in: .whitespaces)
        }
        for suffix in ["kcal", "cal", "mg", "g"] where text.hasSuffix(suffix) {
            text = String(text.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
            break
        }
        if text.contains(",") {
            // Only "1,234" / "1,234.5" style thousands separators are accepted; a decimal comma is ambiguous.
            let parts = text.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            let groups = parts[0].split(separator: ",", omittingEmptySubsequences: false)
            let commaAfterPoint = parts.count > 1 && parts[1].contains(",")
            let valid = groups.count > 1 && (1...3).contains(groups[0].count) && groups.dropFirst().allSatisfy { $0.count == 3 }
                && groups.allSatisfy { $0.allSatisfy(\.isNumber) } && !commaAfterPoint
            guard valid else { return .invalid }
            text = text.replacingOccurrences(of: ",", with: "")
        }
        guard let value = Double(text), value.isFinite else { return .invalid }
        return lessThan ? .lessThan(value) : .value(value)
    }

    // MARK: Header handling

    private struct Header {
        var text: [String: Int] = [:]
        var nutrients: [(Nutrient, Int)] = []
        var unknown: [String] = []

        init(_ cells: [String]) {
            for (index, cell) in cells.enumerated() {
                let name = LibraryImporter.normalizeHeader(cell)
                if let key = LibraryImporter.textColumns.first(where: { $0.value.contains(name) })?.key, text[key] == nil {
                    text[key] = index
                } else if let nutrient = LibraryImporter.nutrientColumns.first(where: { $0.1.contains(name) })?.0,
                          !nutrients.contains(where: { $0.0 == nutrient }) {
                    nutrients.append((nutrient, index))
                } else if !name.isEmpty {
                    unknown.append(cell)
                }
            }
        }

        func value(_ key: String, in row: [String]) -> String {
            guard let index = text[key], index < row.count else { return "" }
            return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: Entry point

    /// Imports a menu CSV (one row per item or size) and an optional modifiers CSV into restaurants.
    /// Rows with errors are skipped and reported; warnings keep the row but flag suspicious numbers.
    public static func importMenu(csv: String, modifiersCSV: String? = nil, policy: ImportPolicy = ImportPolicy()) -> ImportReport {
        var report = ImportReport()
        func issue(_ severity: ImportIssue.Severity, _ code: ImportIssue.Code, _ row: Int?, _ message: String) {
            report.issues.append(ImportIssue(severity: severity, code: code, row: row, message: message))
        }

        let menuRows: [[String]]
        do { menuRows = try CSV.parse(csv) } catch {
            issue(.error, .rowShape, nil, "The menu file has an unterminated quoted field.")
            return report
        }
        guard let headerCells = menuRows.first else {
            issue(.error, .missingColumn, nil, "The menu file is empty.")
            return report
        }
        let header = Header(headerCells)
        for required in ["restaurant", "item"] where header.text[required] == nil {
            issue(.error, .missingColumn, 1, "Missing required column: \(required).")
        }
        if !header.nutrients.contains(where: { $0.0 == .energyKcal }) {
            issue(.error, .missingColumn, 1, "Missing required column: calories.")
        }
        if report.hasErrors { return report }
        for name in header.unknown { issue(.info, .unknownColumn, 1, "Ignoring unknown column \"\(name)\".") }

        // Modifier groups first so items can reference them.
        var groupsByRestaurant: [String: [ModifierGroup]] = [:]
        if let modifiersCSV {
            groupsByRestaurant = importModifiers(modifiersCSV, policy: policy, report: &report)
        }

        var builders: [String: RestaurantBuilder] = [:]
        var order: [String] = []

        for (offset, row) in menuRows.dropFirst().enumerated() {
            let rowNumber = offset + 2
            report.rowsRead += 1

            if row.count > headerCells.count {
                issue(.error, .rowShape, rowNumber, "Row has \(row.count) fields but the header has \(headerCells.count); an unquoted comma?")
                continue
            }
            let restaurantName = header.value("restaurant", in: row)
            let itemName = header.value("item", in: row)
            if restaurantName.isEmpty || itemName.isEmpty {
                issue(.error, .missingValue, rowNumber, "Restaurant and item names are required.")
                continue
            }

            // Nutrients.
            var nutrients = NutrientSet()
            var rowFailed = false
            for (nutrient, column) in header.nutrients {
                let cell = column < row.count ? row[column] : ""
                switch parseNumber(cell) {
                case .missing: continue
                case let .value(value):
                    if value < 0 {
                        issue(.error, .negativeValue, rowNumber, "\(nutrient.rawValue) is negative (\(cell)).")
                        rowFailed = true
                    } else {
                        nutrients[nutrient] = value
                    }
                case let .lessThan(bound):
                    nutrients[nutrient] = bound / 2
                    issue(.info, .lessThanValue, rowNumber, "\(nutrient.rawValue) \"<\(bound)\" stored as \(bound / 2).")
                case .invalid:
                    issue(.error, .invalidNumber, rowNumber, "\(nutrient.rawValue) is not a number: \"\(cell)\".")
                    rowFailed = true
                }
            }
            if !rowFailed, nutrients.calories == nil {
                issue(.error, .missingValue, rowNumber, "Calories are required for \(itemName).")
                rowFailed = true
            }

            // Provenance.
            let provenance = resolveProvenance(header: header, row: row, policy: policy)
            if provenance.license == .unknown, policy.requireKnownLicense {
                issue(.error, .licenseUnknown, rowNumber, "No recognised license for \(itemName); refusing to import data of unknown terms.")
                rowFailed = true
            }
            if rowFailed { continue }

            let slug = Slug.make(restaurantName)
            if builders[slug] == nil {
                let category = RestaurantCategory(rawValue: header.value("restaurant_category", in: row).lowercased()) ?? .other
                let region = header.value("region", in: row).uppercased()
                builders[slug] = RestaurantBuilder(
                    id: slug, name: restaurantName, category: category,
                    region: region.isEmpty ? policy.defaultRegion : region, provenance: provenance,
                    modifierGroups: groupsByRestaurant[slug] ?? []
                )
                order.append(slug)
            }
            guard var builder = builders[slug] else { continue }

            let section = header.value("section", in: row).isEmpty ? "Menu" : header.value("section", in: row)
            let variantName = header.value("variant", in: row)
            let servingGrams: Double? = {
                if case let .value(grams) = parseNumber(header.value("serving_g", in: row)) { return grams }
                return nil
            }()

            // Free-text tag columns.
            let allergens = parseTags(header.value("allergens", in: row), table: allergenNames, row: rowNumber, code: .unknownAllergen, kind: "allergen", report: &report)
            let diet = parseTags(header.value("diet", in: row), table: dietNames, row: rowNumber, code: .unknownDietTag, kind: "diet tag", report: &report)
            let groupNames = header.value("groups", in: row).split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let aliases = header.value("aliases", in: row).split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

            let sectionSlug = Slug.make(section)
            let itemSlug = Slug.make(itemName)

            if let existing = builder.itemIndex(name: itemName, section: section) {
                // Another row for an item already seen: a size/variant row, or a duplicate.
                if variantName.isEmpty {
                    issue(.error, .duplicateItem, rowNumber, "\(itemName) appears twice in \(section).")
                    continue
                }
                let variantID = Slug.make(variantName)
                if builder.items[existing].variants.contains(where: { $0.id == variantID }) {
                    issue(.error, .duplicateItem, rowNumber, "\(itemName) / \(variantName) appears twice.")
                    continue
                }
                builder.items[existing].variants.append(ItemVariant(id: variantID, name: variantName, nutrients: nutrients))
                let probe = MenuItem(id: "probe", name: "\(itemName) (\(variantName))", section: section, nutrients: nutrients)
                for warning in sanityWarnings(for: probe, policy: policy) {
                    issue(.warning, warning.code, rowNumber, warning.message)
                }
            } else {
                var id = "\(slug)/\(itemSlug)"
                if builder.items.contains(where: { $0.id == id }) { id += "-\(sectionSlug)" }
                var item = MenuItem(
                    id: id, name: itemName, section: section, aliases: aliases,
                    description: header.value("description", in: row).isEmpty ? nil : header.value("description", in: row),
                    servingDescription: header.value("serving", in: row).isEmpty ? nil : header.value("serving", in: row),
                    servingGrams: servingGrams, nutrients: nutrients, allergens: allergens, dietTags: diet
                )
                if provenance != builder.provenance { item.provenance = provenance }
                for name in groupNames {
                    if let group = builder.modifierGroups.first(where: { $0.id == "\(slug)/\(Slug.make(name))" }) {
                        item.modifierGroupIDs.append(group.id)
                    } else {
                        issue(.warning, .unknownModifierGroup, rowNumber, "\(itemName) refers to unknown modifier group \"\(name)\".")
                    }
                }
                if !variantName.isEmpty {
                    // The first row doubles as the listed build and as the named size.
                    item.variants.append(ItemVariant(id: Slug.make(variantName), name: variantName, nutrients: nutrients))
                }
                builder.items.append(item)
                for warning in sanityWarnings(for: item, policy: policy) {
                    issue(.warning, warning.code, rowNumber, warning.message)
                }
            }
            builders[slug] = builder
            report.rowsImported += 1
        }

        report.restaurants = order.compactMap { builders[$0]?.build() }
        return report
    }

    // MARK: Pieces

    private struct RestaurantBuilder {
        let id: String
        let name: String
        let category: RestaurantCategory
        let region: String?
        let provenance: Provenance
        var modifierGroups: [ModifierGroup]
        var items: [MenuItem] = []

        init(id: String, name: String, category: RestaurantCategory, region: String?, provenance: Provenance, modifierGroups: [ModifierGroup]) {
            self.id = id
            self.name = name
            self.category = category
            self.region = region
            self.provenance = provenance
            self.modifierGroups = modifierGroups
        }

        func itemIndex(name: String, section: String) -> Int? {
            items.firstIndex { $0.name.caseInsensitiveCompare(name) == .orderedSame && $0.section.caseInsensitiveCompare(section) == .orderedSame }
        }

        func build() -> Restaurant {
            Restaurant(id: id, name: name, category: category, region: region, provenance: provenance, items: items, modifierGroups: modifierGroups)
        }
    }

    private static func resolveProvenance(header: Header, row: [String], policy: ImportPolicy) -> Provenance {
        let licenseText = header.value("license", in: row)
        let name = header.value("source_name", in: row)
        let fallback = policy.defaultProvenance

        let kind = ProvenanceKind(rawValue: header.value("source_kind", in: row)) ?? fallback?.kind ?? .officialChain
        let license: LicenseTag = licenseText.isEmpty ? (fallback?.license ?? .unknown) : LicenseTag(parsing: licenseText)
        let url = header.value("source_url", in: row)
        let asOf = header.value("as_of", in: row)
        return Provenance(
            kind: kind,
            sourceName: name.isEmpty ? (fallback?.sourceName ?? "Unspecified") : name,
            sourceURL: url.isEmpty ? fallback?.sourceURL : url,
            license: license,
            asOf: asOf.isEmpty ? (fallback?.asOf ?? "unknown") : asOf
        )
    }

    private static func parseTags<T>(_ text: String, table: [String: T], row: Int, code: ImportIssue.Code, kind: String, report: inout ImportReport) -> Set<T> {
        var result: Set<T> = []
        for part in text.split(whereSeparator: { ";|/".contains($0) }) {
            let key = part.lowercased().filter { $0.isLetter }
            if key.isEmpty { continue }
            if let value = table[key] {
                result.insert(value)
            } else {
                report.issues.append(ImportIssue(severity: .warning, code: code, row: row, message: "Unknown \(kind) \"\(part.trimmingCharacters(in: .whitespaces))\"."))
            }
        }
        return result
    }

    /// Plausibility checks that catch unit slips and typos in published nutrition.
    static func sanityWarnings(for item: MenuItem, policy: ImportPolicy) -> [(code: ImportIssue.Code, message: String)] {
        var warnings: [(code: ImportIssue.Code, message: String)] = []
        let n = item.nutrients
        if let declared = n.calories {
            if declared > 4000 {
                warnings.append((code: .implausibleCalories, message: "\(item.name): \(Int(declared)) kcal is very high for one item; kJ or a shared platter?"))
            }
            if let computed = n.atwaterKcal {
                let allowed = max(policy.energyAbsoluteTolerance, policy.energyRelativeTolerance * max(declared, computed))
                if abs(declared - computed) > allowed {
                    warnings.append((code: .energyMismatch, message: "\(item.name): \(Int(declared)) kcal does not match 4P+4C+9F = \(Int(computed)) kcal."))
                }
            }
            if let sodium = n[.sodium], declared >= 100, sodium > 0, sodium < 5 {
                warnings.append((code: .implausibleSodium, message: "\(item.name): sodium \(sodium) mg looks like grams."))
            }
        }
        for (part, whole) in [(Nutrient.saturatedFat, Nutrient.fat), (.sugars, .carbohydrate), (.fiber, .carbohydrate), (.addedSugars, .sugars)] {
            if let p = n[part], let w = n[whole], p > w + 0.5 {
                warnings.append((code: .partsExceedWhole, message: "\(item.name): \(part.rawValue) (\(p)) exceeds \(whole.rawValue) (\(w))."))
            }
        }
        if let grams = item.servingGrams, let p = n.proteinG, let c = n.carbsG, let f = n.fatG, p + c + f > grams + 1 {
            warnings.append((code: .macrosExceedServing, message: "\(item.name): macros total \(p + c + f) g in a \(grams) g serving."))
        }
        return warnings
    }

    // MARK: Modifiers

    private static func importModifiers(_ csv: String, policy: ImportPolicy, report: inout ImportReport) -> [String: [ModifierGroup]] {
        func issue(_ severity: ImportIssue.Severity, _ code: ImportIssue.Code, _ row: Int?, _ message: String) {
            report.issues.append(ImportIssue(severity: severity, code: code, row: row, message: message))
        }
        guard let rows = try? CSV.parse(csv), let headerCells = rows.first else {
            issue(.error, .rowShape, nil, "The modifiers file is empty or malformed.")
            return [:]
        }
        let header = Header(headerCells)
        for required in ["restaurant", "group", "option"] where header.text[required] == nil {
            issue(.error, .missingColumn, 1, "Modifiers file: missing required column \(required).")
        }
        if header.text["restaurant"] == nil || header.text["group"] == nil || header.text["option"] == nil { return [:] }

        var groups: [String: [ModifierGroup]] = [:]
        for (offset, row) in rows.dropFirst().enumerated() {
            let rowNumber = offset + 2
            let restaurant = Slug.make(header.value("restaurant", in: row))
            let groupName = header.value("group", in: row)
            let optionName = header.value("option", in: row)
            if restaurant.isEmpty || groupName.isEmpty || optionName.isEmpty {
                issue(.error, .missingValue, rowNumber, "Modifier rows need restaurant, group and option.")
                continue
            }
            var delta = NutrientSet()
            var failed = false
            for (nutrient, column) in header.nutrients {
                switch parseNumber(column < row.count ? row[column] : "") {
                case .missing: continue
                case let .value(value): delta[nutrient] = value
                case let .lessThan(bound): delta[nutrient] = bound / 2
                case .invalid:
                    issue(.error, .invalidNumber, rowNumber, "Modifier \(optionName): \(nutrient.rawValue) is not a number.")
                    failed = true
                }
            }
            if failed { continue }

            let groupID = "\(restaurant)/\(Slug.make(groupName))"
            let option = ModifierOption(
                id: "\(groupID)/\(Slug.make(optionName))", name: optionName, delta: delta,
                isDefault: ["yes", "y", "true", "1", "included"].contains(header.value("default", in: row).lowercased())
            )
            var list = groups[restaurant] ?? []
            if let index = list.firstIndex(where: { $0.id == groupID }) {
                if list[index].options.contains(where: { $0.id == option.id }) {
                    issue(.error, .duplicateOption, rowNumber, "Option \(optionName) appears twice in \(groupName).")
                    continue
                }
                list[index].options.append(option)
            } else {
                list.append(ModifierGroup(id: groupID, name: groupName, rule: parseRule(header.value("rule", in: row)), options: [option]))
            }
            groups[restaurant] = list
        }
        return groups
    }

    static func parseRule(_ text: String) -> SelectionRule {
        let key = text.lowercased().filter { $0.isLetter || $0.isNumber }
        if key.isEmpty || key == "multiple" || key == "many" { return .multiple(max: nil) }
        if key == "single" || key == "one" { return .single(required: false) }
        if key == "singlerequired" || key == "required" || key == "onerequired" { return .single(required: true) }
        if key.hasPrefix("multiple") || key.hasPrefix("max"), let cap = Int(key.filter(\.isNumber)) { return .multiple(max: cap) }
        return .multiple(max: nil)
    }
}
