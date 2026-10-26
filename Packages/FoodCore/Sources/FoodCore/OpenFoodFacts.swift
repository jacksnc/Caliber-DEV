import Foundation

/// Open Food Facts product API (v2) request building and response mapping.
///
/// Licensing: the database is ODbL and the images CC BY-SA. Showing looked-up products with attribution is fine, but
/// bulk-copying records into a database you redistribute triggers share-alike. Send a descriptive User-Agent with a
/// contact address, as their API terms ask.
public enum OpenFoodFacts {
    public static let defaultBaseURL = URL(string: "https://world.openfoodfacts.org")!

    /// Only the fields the mapper reads, which keeps responses small.
    public static let fields = [
        "code", "product_name", "product_name_en", "generic_name", "brands", "quantity", "product_quantity",
        "serving_size", "serving_quantity", "nutrition_data_per", "nutriments", "categories_tags",
        "allergens_tags", "traces_tags", "ingredients_text", "last_modified_t",
    ]

    /// Keys to try, most likely first. Open Food Facts stores UPC-A and EAN-8 codes zero-padded to 13 digits, but the
    /// shorter spelling is kept as a fallback because the exact normalisation cannot be checked offline.
    public static func requestKeys(for gtin: GTIN) -> [String] {
        let unit = gtin.consumerUnit
        guard let ean13 = unit.ean13 else { return [unit.digits14] }
        var keys = [ean13]
        if unit.shortest != ean13 { keys.append(unit.shortest) }
        return keys
    }

    public static func productRequest(key: String, userAgent: String, base: URL = defaultBaseURL) -> HTTPRequest {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false) ?? URLComponents()
        components.path = "/api/v2/product/\(key).json"
        components.queryItems = [URLQueryItem(name: "fields", value: fields.joined(separator: ","))]
        return HTTPRequest(url: components.url ?? base, headers: ["User-Agent": userAgent, "Accept": "application/json"])
    }

    // MARK: Mapping

    private struct NutrimentField {
        let key: String
        let nutrient: Nutrient
        /// Open Food Facts `_100g` / `_serving` values are grams for everything except energy.
        let perGram: Double
    }

    private static let table: [NutrimentField] = [
        NutrimentField(key: "proteins", nutrient: .protein, perGram: 1),
        NutrimentField(key: "carbohydrates", nutrient: .carbohydrate, perGram: 1),
        NutrimentField(key: "fat", nutrient: .fat, perGram: 1),
        NutrimentField(key: "saturated-fat", nutrient: .saturatedFat, perGram: 1),
        NutrimentField(key: "trans-fat", nutrient: .transFat, perGram: 1),
        NutrimentField(key: "monounsaturated-fat", nutrient: .monounsaturatedFat, perGram: 1),
        NutrimentField(key: "polyunsaturated-fat", nutrient: .polyunsaturatedFat, perGram: 1),
        NutrimentField(key: "cholesterol", nutrient: .cholesterol, perGram: 1000),
        NutrimentField(key: "sodium", nutrient: .sodium, perGram: 1000),
        NutrimentField(key: "fiber", nutrient: .fiber, perGram: 1),
        NutrimentField(key: "sugars", nutrient: .sugars, perGram: 1),
        NutrimentField(key: "added-sugars", nutrient: .addedSugars, perGram: 1),
        NutrimentField(key: "polyols", nutrient: .sugarAlcohols, perGram: 1),
        NutrimentField(key: "potassium", nutrient: .potassium, perGram: 1000),
        NutrimentField(key: "calcium", nutrient: .calcium, perGram: 1000),
        NutrimentField(key: "iron", nutrient: .iron, perGram: 1000),
        NutrimentField(key: "magnesium", nutrient: .magnesium, perGram: 1000),
        NutrimentField(key: "zinc", nutrient: .zinc, perGram: 1000),
        NutrimentField(key: "vitamin-d", nutrient: .vitaminD, perGram: 1_000_000),
        NutrimentField(key: "vitamin-c", nutrient: .vitaminC, perGram: 1000),
        NutrimentField(key: "caffeine", nutrient: .caffeine, perGram: 1000),
    ]

    private static func nutrients(from nutriments: JSONValue?, suffix: String) -> NutrientSet? {
        guard let nutriments else { return nil }
        var set = NutrientSet()
        if let kcal = nutriments["energy-kcal_\(suffix)"]?.double {
            set[.energyKcal] = kcal
        } else if let kilojoules = nutriments["energy-kj_\(suffix)"]?.double ?? nutriments["energy_\(suffix)"]?.double {
            set[.energyKcal] = NutrientSet.clean(kilojoules * NutritionReference.kcalPerKilojoule)
        }
        for field in table {
            if let grams = nutriments["\(field.key)_\(suffix)"]?.double {
                set[field.nutrient] = NutrientSet.clean(grams * field.perGram)
            }
        }
        if set[.sodium] == nil, let salt = nutriments["salt_\(suffix)"]?.double {
            set[.sodium] = NutrientSet.clean(salt * NutritionReference.saltToSodium * 1000)
        }
        return set.isEmpty ? nil : set
    }

    private static func cleaned(_ value: JSONValue?) -> String? {
        guard let text = value?.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    public static func map(_ data: Data, requested: GTIN? = nil, now: Date = Date()) -> MappingOutcome {
        let json: JSONValue
        do { json = try JSONValue.parse(data) } catch { return .malformed("not JSON: \(error)") }
        guard json.object != nil else { return .malformed("expected a JSON object") }

        if let status = json["status"]?.int, status == 0 { return .notFound }
        guard let product = json["product"], product.object != nil else { return .malformed("response has no product") }

        let code = cleaned(product["code"]) ?? cleaned(json["code"]) ?? ""
        let gtin = requested ?? GTIN(code)

        let name = cleaned(product["product_name"]) ?? cleaned(product["product_name_en"]) ?? cleaned(product["generic_name"]) ?? ""
        let brand = cleaned(product["brands"]).flatMap { $0.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } }

        var serving = cleaned(product["serving_size"]).flatMap(ServingParser.parse)
        let packageSize = cleaned(product["quantity"]).flatMap(ServingParser.parsePackage)

        let categories = product["categories_tags"]?.strings ?? []
        let liquidCategory = categories.contains { $0.contains("beverages") || $0.contains("waters") || $0.contains("drinks") }
        let liquidServing = (serving?.milliliters != nil && serving?.grams == nil)
        let liquidPackage = (packageSize?.milliliters != nil && packageSize?.grams == nil)
        let isLiquid = liquidServing || liquidPackage || (liquidCategory && serving?.grams == nil)

        // `serving_quantity` is the serving weight (g) or volume (ml) as a number.
        if let quantity = product["serving_quantity"]?.double, quantity > 0 {
            if serving == nil {
                serving = ServingSize(quantity: quantity, unit: isLiquid ? "ml" : "g",
                                      grams: isLiquid ? nil : quantity, milliliters: isLiquid ? quantity : nil,
                                      text: cleaned(product["serving_size"]) ?? "\(quantity)")
            } else if serving?.grams == nil, serving?.milliliters == nil {
                serving?.grams = isLiquid ? nil : quantity
                serving?.milliliters = isLiquid ? quantity : nil
            }
        }

        let nutriments = product["nutriments"]
        let per100 = nutrients(from: nutriments, suffix: "100g")
        let perServing = nutrients(from: nutriments, suffix: "serving")

        var record = FoodRecord(
            id: "off:\(code.isEmpty ? (gtin?.digits14 ?? "unknown") : code)",
            gtin: gtin,
            name: name,
            brand: brand,
            source: .openFoodFacts,
            per100g: isLiquid ? nil : per100,
            per100ml: isLiquid ? per100 : nil,
            perServing: perServing,
            serving: serving,
            packageSize: packageSize,
            ingredients: cleaned(product["ingredients_text"]),
            allergens: AllergenTags.fromOpenFoodFacts(product["allergens_tags"]?.strings ?? []),
            traces: AllergenTags.fromOpenFoodFacts(product["traces_tags"]?.strings ?? []),
            fetchedAt: now
        )
        record.flags = NutritionValidator.validate(record)
        return .found(record)
    }
}
