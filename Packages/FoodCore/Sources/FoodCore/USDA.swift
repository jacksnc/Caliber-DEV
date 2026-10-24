import Foundation

/// USDA FoodData Central request building and response mapping for Branded foods.
///
/// FoodData Central content is public domain (CC0). An API key is required and rate limited; keep it on a server or
/// edge function and point `base` there rather than shipping the key inside the app.
public enum USDAFoodDataCentral {
    public static let defaultBaseURL = URL(string: "https://api.nal.usda.gov/fdc/v1")!

    /// Codes to try, most likely first. Branded records usually store the 12-digit UPC, but 13- and 14-digit
    /// spellings exist, so the search can be repeated with the next key when nothing matches.
    public static func searchKeys(for gtin: GTIN) -> [String] {
        var keys: [String] = []
        for key in [gtin.upcA, gtin.ean13, gtin.digits14, gtin.ean8] {
            if let key, !keys.contains(key) { keys.append(key) }
        }
        return keys
    }

    public static func searchRequest(key: String, apiKey: String?, base: URL = defaultBaseURL, pageSize: Int = 10) -> HTTPRequest {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false) ?? URLComponents()
        components.path = components.path.hasSuffix("/") ? components.path + "foods/search" : components.path + "/foods/search"
        components.queryItems = [
            URLQueryItem(name: "query", value: key),
            URLQueryItem(name: "dataType", value: "Branded"),
            URLQueryItem(name: "pageSize", value: String(pageSize)),
        ]
        var headers = ["Accept": "application/json"]
        if let apiKey { headers["X-Api-Key"] = apiKey }
        return HTTPRequest(url: components.url ?? base, headers: headers)
    }

    // MARK: Nutrient numbers

    /// FoodData Central nutrient numbers. 208/268 are energy in kcal/kJ; 328/324 are vitamin D in mcg/IU.
    private static let numbers: [String: Nutrient] = [
        "203": .protein, "204": .fat, "205": .carbohydrate, "291": .fiber, "269": .sugars, "269.3": .sugars,
        "539": .addedSugars, "606": .saturatedFat, "605": .transFat, "645": .monounsaturatedFat, "646": .polyunsaturatedFat,
        "601": .cholesterol, "307": .sodium, "306": .potassium, "301": .calcium, "303": .iron, "304": .magnesium,
        "309": .zinc, "328": .vitaminD, "401": .vitaminC, "262": .caffeine, "221": .alcohol,
    ]

    /// Converts `value` expressed in `unit` into the canonical unit of `nutrient`.
    static func convert(_ value: Double, from unit: String, to nutrient: Nutrient) -> Double? {
        let from = unit.lowercased()
        let target = nutrient.unit
        let fromGrams: Double?
        switch from {
        case "g", "grm": fromGrams = 1
        case "mg", "mgm": fromGrams = 1e-3
        case "ug", "µg", "μg", "mcg", "mcgm": fromGrams = 1e-6
        case "kcal", "cal": return target == .kcal ? value : nil
        case "kj": return target == .kcal ? value * NutritionReference.kcalPerKilojoule : nil
        case "iu":
            // Only vitamin D has a defined IU conversion here.
            return nutrient == .vitaminD ? value / NutritionReference.iuPerMcgVitaminD : nil
        default: fromGrams = nil
        }
        guard let fromGrams, let targetGrams = target.gramsPerUnit else { return nil }
        return NutrientSet.clean(value * fromGrams / targetGrams)
    }

    static func nutrients(fromFoodNutrients list: [JSONValue]) -> NutrientSet? {
        var set = NutrientSet()
        var energyKcal: Double?
        var energyKJ: Double?
        var vitaminDIU: Double?
        for entry in list {
            let number = entry["nutrientNumber"]?.string ?? entry["nutrient"]?["number"]?.string ?? ""
            guard let value = entry["value"]?.double ?? entry["amount"]?.double else { continue }
            let unit = entry["unitName"]?.string ?? entry["nutrient"]?["unitName"]?.string ?? ""
            switch number {
            case "208": energyKcal = convert(value, from: unit.isEmpty ? "kcal" : unit, to: .energyKcal) ?? energyKcal
            case "268": energyKJ = convert(value, from: unit.isEmpty ? "kj" : unit, to: .energyKcal) ?? energyKJ
            case "324": vitaminDIU = convert(value, from: "iu", to: .vitaminD) ?? vitaminDIU
            default:
                if let nutrient = numbers[number], let converted = convert(value, from: unit.isEmpty ? nutrient.unit.rawValue : unit, to: nutrient) {
                    set[nutrient] = converted
                }
            }
        }
        if let energyKcal { set[.energyKcal] = energyKcal } else if let energyKJ { set[.energyKcal] = NutrientSet.clean(energyKJ) }
        if set[.vitaminD] == nil, let vitaminDIU { set[.vitaminD] = NutrientSet.clean(vitaminDIU) }
        return set.isEmpty ? nil : set
    }

    /// `labelNutrients` are per serving, in the same units the label prints.
    static func nutrients(fromLabel label: JSONValue?) -> NutrientSet? {
        guard let label, label.object != nil else { return nil }
        let keys: [(String, Nutrient)] = [
            ("calories", .energyKcal), ("protein", .protein), ("fat", .fat), ("carbohydrates", .carbohydrate),
            ("fiber", .fiber), ("sugars", .sugars), ("addedSugar", .addedSugars), ("saturatedFat", .saturatedFat),
            ("transFat", .transFat), ("cholesterol", .cholesterol), ("sodium", .sodium), ("potassium", .potassium),
            ("calcium", .calcium), ("iron", .iron),
        ]
        var set = NutrientSet()
        for (key, nutrient) in keys {
            if let value = label[key]?["value"]?.double { set[nutrient] = value }
        }
        return set.isEmpty ? nil : set
    }

    // MARK: Mapping

    /// Picks the record whose `gtinUpc` equals `gtin` (compared as zero-padded GTIN-14), newest first.
    public static func mapSearch(_ data: Data, matching gtin: GTIN, now: Date = Date()) -> MappingOutcome {
        let json: JSONValue
        do { json = try JSONValue.parse(data) } catch { return .malformed("not JSON: \(error)") }
        guard json.object != nil else { return .malformed("expected a JSON object") }
        guard let foods = json["foods"]?.array else { return .malformed("response has no foods list") }

        let matches = foods.filter { food in
            guard let code = food["gtinUpc"]?.string?.filter({ $0.isASCII && $0.isNumber }), !code.isEmpty, code.count <= 14 else { return false }
            return String(repeating: "0", count: 14 - code.count) + code == gtin.digits14
        }
        let newest = matches.max { a, b in
            (a["modifiedDate"]?.string ?? a["availableDate"]?.string ?? "") < (b["modifiedDate"]?.string ?? b["availableDate"]?.string ?? "")
        }
        guard let food = newest else { return .notFound }
        return .found(record(from: food, gtin: gtin, now: now))
    }

    /// Maps a single `/food/{fdcId}` response.
    public static func mapFood(_ data: Data, now: Date = Date()) -> MappingOutcome {
        let json: JSONValue
        do { json = try JSONValue.parse(data) } catch { return .malformed("not JSON: \(error)") }
        guard json.object != nil, json["fdcId"] != nil else { return .malformed("not a food object") }
        let code = json["gtinUpc"]?.string?.filter { $0.isASCII && $0.isNumber } ?? ""
        let padded = code.isEmpty || code.count > 14 ? nil : String(repeating: "0", count: 14 - code.count) + code
        return .found(record(from: json, gtin: padded.flatMap { GTIN($0) }, now: now))
    }

    static func record(from food: JSONValue, gtin: GTIN?, now: Date) -> FoodRecord {
        let fdcId = food["fdcId"]?.string ?? "unknown"
        let description = food["description"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let brand = (food["brandName"]?.string ?? food["brandOwner"]?.string)?.trimmingCharacters(in: .whitespacesAndNewlines)

        // Branded nutrient amounts are per 100 g, or per 100 ml when the serving is a volume.
        let servingUnit = (food["servingSizeUnit"]?.string ?? "g").lowercased()
        let isLiquid = servingUnit == "ml" || servingUnit == "mlt"
        let per100 = nutrients(fromFoodNutrients: food["foodNutrients"]?.array ?? [])
        let perServing = nutrients(fromLabel: food["labelNutrients"])

        var serving: ServingSize?
        if let amount = food["servingSize"]?.double, amount > 0 {
            let household = food["householdServingFullText"]?.string.flatMap { ServingParser.parse($0) }
            serving = ServingSize(
                quantity: household?.quantity ?? amount,
                unit: household?.unit ?? (isLiquid ? "ml" : "g"),
                grams: isLiquid ? nil : amount,
                milliliters: isLiquid ? amount : household?.milliliters,
                text: food["householdServingFullText"]?.string ?? "\(amount) \(isLiquid ? "ml" : "g")"
            )
        }

        let ingredients = food["ingredients"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
        var record = FoodRecord(
            id: "usda:\(fdcId)",
            gtin: gtin,
            name: description,
            brand: brand?.isEmpty == false ? brand : nil,
            source: .usdaBranded,
            per100g: isLiquid ? nil : per100,
            per100ml: isLiquid ? per100 : nil,
            perServing: perServing,
            serving: serving,
            packageSize: food["packageWeight"]?.string.flatMap { ServingParser.parsePackage($0) },
            ingredients: ingredients?.isEmpty == false ? ingredients : nil,
            allergens: ingredients.map { AllergenDetector.possibleAllergens(in: $0) } ?? [],
            fetchedAt: now
        )
        record.flags = NutritionValidator.validate(record)
        return record
    }
}
