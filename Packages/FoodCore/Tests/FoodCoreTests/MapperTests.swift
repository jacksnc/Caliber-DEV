import XCTest
@testable import FoodCore

/// All fixtures are SYNTHETIC: the field names follow the public Open Food Facts and FoodData Central API
/// documentation, but the products, brands and numbers are invented. (Real payloads could not be fetched while
/// writing these tests; verify against live responses in an integration pass.)
final class MapperTests: XCTestCase {
    static let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: Open Food Facts

    static let offCereal = """
    {
      "code": "0012345678905",
      "status": 1,
      "status_verbose": "product found",
      "product": {
        "code": "0012345678905",
        "product_name": "Sunny Oat Crunch",
        "brands": "Fictional Foods Co.,Sunny",
        "quantity": "340 g",
        "serving_size": "2/3 cup (55 g)",
        "serving_quantity": 55,
        "nutrition_data_per": "100g",
        "categories_tags": ["en:breakfast-cereals"],
        "allergens_tags": ["en:gluten", "en:milk"],
        "traces_tags": ["en:nuts", "en:soybeans"],
        "ingredients_text": "Whole grain oats, sugar, canola oil, salt.",
        "nutriments": {
          "energy-kcal_100g": 418, "energy_100g": 1749, "proteins_100g": 5.45, "carbohydrates_100g": 67.27,
          "sugars_100g": 21.82, "added-sugars_100g": 18.18, "fat_100g": 14.55, "saturated-fat_100g": 1.82,
          "trans-fat_100g": 0, "cholesterol_100g": 0, "fiber_100g": 7.27, "sodium_100g": 0.291, "salt_100g": 0.7275,
          "potassium_100g": 0.427, "calcium_100g": 0.473, "iron_100g": 0.0145, "vitamin-d_100g": 0.00000364,
          "energy-kcal_serving": 230, "proteins_serving": 3, "carbohydrates_serving": 37, "sugars_serving": 12,
          "fat_serving": 8, "saturated-fat_serving": 1, "fiber_serving": 4, "sodium_serving": "0.16",
          "cholesterol_serving": 0
        }
      }
    }
    """

    private func found(_ outcome: MappingOutcome, file: StaticString = #filePath, line: UInt = #line) throws -> FoodRecord {
        guard case let .found(record) = outcome else {
            XCTFail("expected found, got \(outcome)", file: file, line: line)
            throw NSError(domain: "test", code: 1)
        }
        return record
    }

    func testOpenFoodFactsCereal() throws {
        let record = try found(OpenFoodFacts.map(Data(Self.offCereal.utf8), requested: GTIN("012345678905"), now: Self.now))
        XCTAssertEqual(record.id, "off:0012345678905")
        XCTAssertEqual(record.gtin, GTIN("012345678905"))
        XCTAssertEqual(record.source, .openFoodFacts)
        XCTAssertEqual(record.name, "Sunny Oat Crunch")
        XCTAssertEqual(record.brand, "Fictional Foods Co.")
        XCTAssertEqual(record.displayName, "Sunny Oat Crunch - Fictional Foods Co.")
        XCTAssertEqual(record.fetchedAt, Self.now)

        let per100 = try XCTUnwrap(record.per100g)
        XCTAssertNil(record.per100ml)
        XCTAssertEqual(per100[.energyKcal], 418)
        XCTAssertEqual(per100[.protein], 5.45)
        XCTAssertEqual(per100[.carbohydrate], 67.27)
        XCTAssertEqual(per100[.fat], 14.55)
        XCTAssertEqual(per100[.sodium], 291, "grams -> milligrams")
        XCTAssertEqual(per100[.potassium], 427)
        XCTAssertEqual(per100[.calcium], 473)
        XCTAssertEqual(per100[.iron], 14.5)
        XCTAssertEqual(per100[.vitaminD], 3.64, "grams -> micrograms without float noise")
        XCTAssertEqual(per100[.cholesterol], 0)

        let perServing = try XCTUnwrap(record.perServing)
        XCTAssertEqual(perServing[.energyKcal], 230)
        XCTAssertEqual(perServing[.sodium], 160, "numeric strings are accepted")
        XCTAssertEqual(perServing[.protein], 3)

        let serving = try XCTUnwrap(record.serving)
        XCTAssertEqual(serving.unit, "cup")
        XCTAssertEqual(serving.grams, 55)
        XCTAssertEqual(record.packageSize?.grams, 340)

        XCTAssertEqual(record.allergens, [.gluten, .milk])
        XCTAssertEqual(record.traces, [.treeNut, .soy])
        XCTAssertEqual(record.flags, [], "a consistent product raises no quality flags")
        XCTAssertTrue(record.hasUsableNutrition)
    }

    func testOpenFoodFactsUsesRequestedGTINEvenWhenCodeIsPadded() throws {
        let record = try found(OpenFoodFacts.map(Data(Self.offCereal.utf8), now: Self.now))
        XCTAssertEqual(record.gtin, GTIN("012345678905"), "13-digit code in the payload normalises to the same GTIN")
    }

    func testOpenFoodFactsEnergyFromKilojoulesAndSaltFallback() throws {
        let json = """
        {"status":1,"product":{"code":"4006381333931","product_name":"Test Biscuit","nutriments":
        {"energy_100g":1046,"proteins_100g":6,"carbohydrates_100g":60,"fat_100g":12,"salt_100g":1.0}}}
        """
        let record = try found(OpenFoodFacts.map(Data(json.utf8), now: Self.now))
        let per100 = try XCTUnwrap(record.per100g)
        XCTAssertEqual(per100[.energyKcal] ?? 0, 250, accuracy: 1e-9)
        XCTAssertEqual(per100[.sodium] ?? 0, 400, accuracy: 1e-9, "1 g salt = 400 mg sodium")
    }

    func testOpenFoodFactsLiquidUsesPer100ml() throws {
        let json = """
        {"status":1,"product":{"code":"0012345678905","product_name":"Fictional Cola","brands":"Pop Co",
        "serving_size":"355 ml","quantity":"6 x 355 ml","categories_tags":["en:beverages"],
        "nutriments":{"energy-kcal_100g":42,"carbohydrates_100g":10.6,"sugars_100g":10.6,"fat_100g":0,"proteins_100g":0,
        "sodium_100g":0.007,"caffeine_100g":0.0096}}}
        """
        let record = try found(OpenFoodFacts.map(Data(json.utf8), now: Self.now))
        XCTAssertNil(record.per100g)
        let per100ml = try XCTUnwrap(record.per100ml)
        XCTAssertEqual(per100ml[.caffeine], 9.6)
        XCTAssertEqual(record.serving?.milliliters, 355)
        XCTAssertEqual(record.packageSize?.milliliters, 2130)
        XCTAssertEqual(record.nutrients(for: .milliliters(355))?[.energyKcal] ?? 0, 149.1, accuracy: 1e-9)
        XCTAssertEqual(record.nutrients(for: .servings(2))?[.energyKcal] ?? 0, 298.2, accuracy: 1e-9)
        XCTAssertEqual(record.nutrients(for: .packages(0.5))?[.energyKcal] ?? 0, 447.3, accuracy: 1e-9)
        XCTAssertNil(record.nutrients(for: .grams(100)), "a drink has no per-gram basis")
    }

    func testOpenFoodFactsServingQuantityFillsMissingWeight() throws {
        let json = """
        {"status":1,"product":{"code":"4006381333931","product_name":"Bar","serving_size":"1 bar","serving_quantity":"40",
        "nutriments":{"energy-kcal_100g":400,"proteins_100g":10,"carbohydrates_100g":50,"fat_100g":16}}}
        """
        let record = try found(OpenFoodFacts.map(Data(json.utf8), now: Self.now))
        XCTAssertEqual(record.serving?.unit, "bar")
        XCTAssertEqual(record.serving?.grams, 40)
        XCTAssertEqual(record.nutrients(for: .servings(1))?[.energyKcal], 160)
    }

    func testOpenFoodFactsNameFallbacksAndSparseProduct() throws {
        let json = """
        {"status":1,"product":{"code":"4006381333931","product_name":"","product_name_en":"English Name","brands":""}}
        """
        let record = try found(OpenFoodFacts.map(Data(json.utf8), now: Self.now))
        XCTAssertEqual(record.name, "English Name")
        XCTAssertNil(record.brand)
        XCTAssertEqual(Set(record.flags), [.missingEnergy, .missingMacros, .noServingSize])
        XCTAssertFalse(record.hasUsableNutrition)

        let nameless = try found(OpenFoodFacts.map(Data("{\"status\":1,\"product\":{\"code\":\"4006381333931\"}}".utf8), now: Self.now))
        XCTAssertTrue(nameless.flags.contains(.missingName))
    }

    func testOpenFoodFactsFlagsKilojoulesStoredAsKilocalories() throws {
        let json = """
        {"status":1,"product":{"code":"4006381333931","product_name":"Mislabelled","nutriments":
        {"energy-kcal_100g":1046,"proteins_100g":6,"carbohydrates_100g":30,"fat_100g":12}}}
        """
        let record = try found(OpenFoodFacts.map(Data(json.utf8), now: Self.now))
        XCTAssertTrue(record.flags.contains(.energyMismatch(declaredKcal: 1046, atwaterKcal: 252)))
        XCTAssertTrue(record.flags.contains(.implausibleEnergyDensity(kcalPer100: 1046)))
        XCTAssertLessThan(FoodQuality.score(record), 0.5 * OpenFoodFacts.map(Data(Self.offCereal.utf8), now: Self.now).qualityScore)
    }

    func testOpenFoodFactsNotFoundAndMalformed() {
        XCTAssertEqual(OpenFoodFacts.map(Data("{\"code\":\"123\",\"status\":0,\"status_verbose\":\"product not found\"}".utf8)), .notFound)
        guard case .malformed = OpenFoodFacts.map(Data("<html>Bad gateway</html>".utf8)) else { return XCTFail() }
        guard case .malformed = OpenFoodFacts.map(Data("[]".utf8)) else { return XCTFail() }
        guard case .malformed = OpenFoodFacts.map(Data("{}".utf8)) else { return XCTFail() }
        guard case .malformed = OpenFoodFacts.map(Data("{\"status\":1}".utf8)) else { return XCTFail() }
    }

    func testOpenFoodFactsRequestKeysAndRequest() throws {
        XCTAssertEqual(OpenFoodFacts.requestKeys(for: try XCTUnwrap(GTIN("036000291452"))), ["0036000291452", "036000291452"])
        XCTAssertEqual(OpenFoodFacts.requestKeys(for: try XCTUnwrap(GTIN("4006381333931"))), ["4006381333931"])
        XCTAssertEqual(OpenFoodFacts.requestKeys(for: try XCTUnwrap(GTIN("96385074"))), ["0000096385074", "96385074"])
        XCTAssertEqual(OpenFoodFacts.requestKeys(for: try XCTUnwrap(GTIN("14006381333938"))), ["4006381333931"], "case codes look up the consumer unit")

        let request = OpenFoodFacts.productRequest(key: "0036000291452", userAgent: "Helios/1.0 (contact@example.invalid)")
        XCTAssertTrue(request.url.absoluteString.hasPrefix("https://world.openfoodfacts.org/api/v2/product/0036000291452.json?fields=code,product_name"))
        XCTAssertEqual(request.headers["User-Agent"], "Helios/1.0 (contact@example.invalid)")
    }

    // MARK: USDA FoodData Central

    static let usdaSearch = """
    {
      "totalHits": 4, "currentPage": 1, "totalPages": 1,
      "foods": [
        {"fdcId": 2000001, "description": "SUNNY OAT CRUNCH", "dataType": "Branded", "gtinUpc": "012345678905",
         "brandOwner": "Fictional Foods Co.", "brandName": "SUNNY", "modifiedDate": "2023-05-02",
         "ingredients": "WHOLE GRAIN OATS, SUGAR.", "servingSize": 55, "servingSizeUnit": "g", "householdServingFullText": "2/3 cup",
         "foodNutrients": [{"nutrientNumber": "208", "unitName": "KCAL", "value": 400}, {"nutrientNumber": "203", "unitName": "G", "value": 5}]},
        {"fdcId": 2000002, "description": "SUNNY OAT CRUNCH CEREAL", "dataType": "Branded", "gtinUpc": "012345678905",
         "brandOwner": "Fictional Foods Co.", "brandName": "SUNNY", "modifiedDate": "2024-03-19",
         "ingredients": "ENRICHED FLOUR (WHEAT FLOUR, NIACIN), SUGAR, PEANUT BUTTER, COCOA BUTTER, WHEY, ALMONDS.",
         "servingSize": 55, "servingSizeUnit": "g", "householdServingFullText": "2/3 cup",
         "foodNutrients": [
           {"nutrientId": 1008, "nutrientNumber": "208", "unitName": "KCAL", "value": 418},
           {"nutrientNumber": "268", "unitName": "kJ", "value": 1749},
           {"nutrientNumber": "203", "unitName": "G", "value": 5.45},
           {"nutrientNumber": "204", "unitName": "G", "value": 14.55},
           {"nutrientNumber": "205", "unitName": "G", "value": 67.27},
           {"nutrientNumber": "269", "unitName": "G", "value": 21.82},
           {"nutrientNumber": "291", "unitName": "G", "value": 7.27},
           {"nutrientNumber": "307", "unitName": "MG", "value": 291},
           {"nutrientNumber": "606", "unitName": "G", "value": 1.82},
           {"nutrientNumber": "601", "unitName": "MG", "value": 0},
           {"nutrientNumber": "306", "unitName": "MG", "value": 427},
           {"nutrientNumber": "301", "unitName": "MG", "value": 473},
           {"nutrientNumber": "303", "unitName": "MG", "value": 14.5},
           {"nutrientNumber": "324", "unitName": "IU", "value": 146}
         ]},
        {"fdcId": 2000003, "description": "SOMETHING ELSE", "dataType": "Branded", "gtinUpc": "098765432108",
         "modifiedDate": "2025-01-01", "foodNutrients": []},
        {"fdcId": 2000004, "description": "OLD ZERO-PADDED LISTING", "dataType": "Branded", "gtinUpc": "00012345678905",
         "modifiedDate": "2019-01-01", "foodNutrients": []}
      ]
    }
    """

    func testUSDASearchPicksNewestMatchingRecord() throws {
        let gtin = try XCTUnwrap(GTIN("012345678905"))
        let record = try found(USDAFoodDataCentral.mapSearch(Data(Self.usdaSearch.utf8), matching: gtin, now: Self.now))
        XCTAssertEqual(record.id, "usda:2000002")
        XCTAssertEqual(record.source, .usdaBranded)
        XCTAssertEqual(record.name, "SUNNY OAT CRUNCH CEREAL")
        XCTAssertEqual(record.brand, "SUNNY")
        XCTAssertEqual(record.gtin, gtin)

        let per100 = try XCTUnwrap(record.per100g)
        XCTAssertEqual(per100[.energyKcal], 418, "kcal wins over kJ when both are present")
        XCTAssertEqual(per100[.protein], 5.45)
        XCTAssertEqual(per100[.sodium], 291)
        XCTAssertEqual(per100[.sugars], 21.82)
        XCTAssertEqual(per100[.vitaminD], 3.65, "146 IU / 40")
        XCTAssertEqual(record.serving?.grams, 55)
        XCTAssertEqual(record.serving?.unit, "cup")
        XCTAssertEqual(record.serving?.quantity ?? 0, 0.666667, accuracy: 1e-6)
        XCTAssertEqual(record.flags, [])
    }

    func testUSDASearchDetectsAllergensFromIngredients() throws {
        let record = try found(USDAFoodDataCentral.mapSearch(Data(Self.usdaSearch.utf8), matching: try XCTUnwrap(GTIN("012345678905"))))
        XCTAssertEqual(record.allergens, [.wheat, .gluten, .peanut, .milk, .treeNut])
    }

    func testUSDASearchNoMatchAndPaddingEquivalence() throws {
        XCTAssertEqual(USDAFoodDataCentral.mapSearch(Data(Self.usdaSearch.utf8), matching: try XCTUnwrap(GTIN("4006381333931"))), .notFound)
        XCTAssertEqual(USDAFoodDataCentral.mapSearch(Data("{\"foods\":[]}".utf8), matching: try XCTUnwrap(GTIN("4006381333931"))), .notFound)
        guard case .malformed = USDAFoodDataCentral.mapSearch(Data("{\"error\":\"bad\"}".utf8), matching: try XCTUnwrap(GTIN("4006381333931"))) else {
            return XCTFail("a response without a foods list is malformed")
        }
        // Only the zero-padded 14-digit listing is left once the newer ones are removed.
        let onlyPadded = """
        {"foods":[{"fdcId":9,"description":"PADDED","gtinUpc":"00012345678905","foodNutrients":[]}]}
        """
        let record = try found(USDAFoodDataCentral.mapSearch(Data(onlyPadded.utf8), matching: try XCTUnwrap(GTIN("012345678905"))))
        XCTAssertEqual(record.id, "usda:9")
    }

    func testUSDAFoodDetailUsesLabelNutrientsPerServing() throws {
        let json = """
        {"fdcId": 2000002, "description": "SUNNY OAT CRUNCH CEREAL", "dataType": "Branded", "gtinUpc": "012345678905",
         "brandOwner": "Fictional Foods Co.", "servingSize": 55.0, "servingSizeUnit": "g", "householdServingFullText": "2/3 cup",
         "labelNutrients": {"fat": {"value": 8.0}, "saturatedFat": {"value": 1.0}, "transFat": {"value": 0.0},
           "cholesterol": {"value": 0.0}, "sodium": {"value": 160.0}, "carbohydrates": {"value": 37.0}, "fiber": {"value": 4.0},
           "sugars": {"value": 12.0}, "protein": {"value": 3.0}, "calcium": {"value": 260.0}, "iron": {"value": 8.0},
           "potassium": {"value": 235.0}, "calories": {"value": 230.0}},
         "foodNutrients": [
           {"type": "FoodNutrient", "id": 1, "nutrient": {"id": 1003, "number": "203", "name": "Protein", "unitName": "g"}, "amount": 5.45},
           {"type": "FoodNutrient", "id": 2, "nutrient": {"id": 1008, "number": "208", "name": "Energy", "unitName": "kcal"}, "amount": 418},
           {"type": "FoodNutrient", "id": 3, "nutrient": {"id": 1004, "number": "204", "name": "Total lipid (fat)", "unitName": "g"}, "amount": 14.55},
           {"type": "FoodNutrient", "id": 4, "nutrient": {"id": 1005, "number": "205", "name": "Carbohydrate, by difference", "unitName": "g"}, "amount": 67.27}
         ]}
        """
        let record = try found(USDAFoodDataCentral.mapFood(Data(json.utf8), now: Self.now))
        XCTAssertEqual(record.gtin, GTIN("012345678905"))
        XCTAssertEqual(record.perServing?[.energyKcal], 230)
        XCTAssertEqual(record.perServing?[.sodium], 160)
        XCTAssertEqual(record.per100g?[.energyKcal], 418)
        XCTAssertEqual(record.nutrients(for: .servings(2))?[.energyKcal], 460)
        XCTAssertEqual(record.nutrients(for: .grams(110))?[.energyKcal] ?? 0, 459.8, accuracy: 1e-9, "per-100 g wins for gram portions")
        guard case .malformed = USDAFoodDataCentral.mapFood(Data("{\"description\":\"x\"}".utf8)) else { return XCTFail() }
    }

    func testUSDALiquidUsesPer100ml() throws {
        let json = """
        {"foods":[{"fdcId": 5, "description": "FICTIONAL COLA", "gtinUpc": "012345678905", "servingSize": 355, "servingSizeUnit": "ml",
         "householdServingFullText": "1 can", "foodNutrients": [{"nutrientNumber": "208", "unitName": "KCAL", "value": 42}]}]}
        """
        let record = try found(USDAFoodDataCentral.mapSearch(Data(json.utf8), matching: try XCTUnwrap(GTIN("012345678905"))))
        XCTAssertNil(record.per100g)
        XCTAssertEqual(record.per100ml?[.energyKcal], 42)
        XCTAssertEqual(record.serving?.milliliters, 355)
    }

    func testUSDAUnitConversion() {
        XCTAssertEqual(USDAFoodDataCentral.convert(0.291, from: "G", to: .sodium), 291)
        XCTAssertEqual(USDAFoodDataCentral.convert(3640, from: "NG", to: .vitaminD), nil, "unknown units are not guessed")
        XCTAssertEqual(USDAFoodDataCentral.convert(3.64, from: "UG", to: .vitaminD), 3.64)
        XCTAssertEqual(USDAFoodDataCentral.convert(1000, from: "kJ", to: .energyKcal) ?? 0, 239.0057, accuracy: 1e-3)
        XCTAssertNil(USDAFoodDataCentral.convert(10, from: "IU", to: .iron))
    }

    func testUSDARequestsAndKeys() throws {
        XCTAssertEqual(USDAFoodDataCentral.searchKeys(for: try XCTUnwrap(GTIN("036000291452"))), ["036000291452", "0036000291452", "00036000291452"])
        XCTAssertEqual(USDAFoodDataCentral.searchKeys(for: try XCTUnwrap(GTIN("4006381333931"))), ["4006381333931", "04006381333931"])
        let request = USDAFoodDataCentral.searchRequest(key: "036000291452", apiKey: "KEY")
        XCTAssertEqual(request.url.absoluteString, "https://api.nal.usda.gov/fdc/v1/foods/search?query=036000291452&dataType=Branded&pageSize=10")
        XCTAssertEqual(request.headers["X-Api-Key"], "KEY", "the key travels in a header, not in the URL")
        XCTAssertNil(USDAFoodDataCentral.searchRequest(key: "1", apiKey: nil).headers["X-Api-Key"])
    }

    // MARK: Allergen detector

    func testAllergenDetector() {
        let cases: [(String, Set<Allergen>)] = [
            ("MILK CHOCOLATE (SUGAR, COCOA BUTTER, SKIM MILK)", [.milk]),
            ("COCOA BUTTER, SUGAR, VANILLA", []),
            ("EGGPLANT, OLIVE OIL, BUTTERNUT SQUASH", []),
            ("SOY LECITHIN, SUGAR", [.soy]),
            ("ALMOND MILK (WATER, ALMONDS)", [.treeNut]),
            ("peanut butter, salt", [.peanut]),
            ("BARLEY MALT SYRUP", [.gluten]),
            ("CONTAINS: SHRIMP, SESAME", [.crustaceanShellfish, .sesame]),
            ("water, salt", []),
            ("sulfur dioxide (preservative)", [.sulphite]),
            ("oat milk, coconut milk, coconut cream", []),
            ("BUTTERMILK, EGG WHITES", [.milk, .egg]),
            ("enriched flour, yeast", [.wheat, .gluten]),
        ]
        for (text, expected) in cases {
            XCTAssertEqual(AllergenDetector.possibleAllergens(in: text), expected, text)
        }
    }

    // MARK: Quality, merging and portions

    private func record(_ source: FoodSource, name: String = "Sunny Oat Crunch", per100g: NutrientSet?, serving: ServingSize? = nil, allergens: Set<Allergen> = []) -> FoodRecord {
        var record = FoodRecord(id: "\(source.rawValue):1", gtin: GTIN("012345678905"), name: name, brand: "Fictional Foods Co.", source: source,
                                per100g: per100g, serving: serving, ingredients: "oats", allergens: allergens)
        record.flags = NutritionValidator.validate(record)
        return record
    }

    func testCompletenessAndScore() {
        let full = NutrientSet([.energyKcal: 418, .protein: 5.45, .carbohydrate: 67.27, .fat: 14.55])
        let serving = ServingSize(quantity: 55, unit: "g", grams: 55, text: "55 g")
        let usda = record(.usdaBranded, per100g: full, serving: serving)
        XCTAssertEqual(FoodQuality.completeness(usda), 1.0, accuracy: 1e-12)
        XCTAssertEqual(FoodQuality.score(usda), 0.9, accuracy: 1e-12)

        let off = record(.openFoodFacts, per100g: full, serving: serving)
        XCTAssertEqual(FoodQuality.score(off), 0.75, accuracy: 1e-12)

        let sparse = record(.openFoodFacts, per100g: NutrientSet([.energyKcal: 418]))
        XCTAssertLessThan(FoodQuality.score(sparse), FoodQuality.score(off))
    }

    func testMergeFillsGapsWithoutOverridingAndKeepsProvenance() throws {
        let usda = record(.usdaBranded, per100g: NutrientSet([.energyKcal: 418, .protein: 5.45, .carbohydrate: 67.27, .fat: 14.55]),
                          serving: ServingSize(quantity: 55, unit: "g", grams: 55, text: "55 g"), allergens: [.milk])
        var off = record(.openFoodFacts, per100g: NutrientSet([.energyKcal: 420, .protein: 5.5, .carbohydrate: 67, .fat: 14.5, .fiber: 7.27, .sodium: 291]),
                         allergens: [.gluten])
        off.traces = [.soy]
        let merged = try XCTUnwrap(FoodMerger.merge([off, usda]))

        XCTAssertEqual(merged.source, .usdaBranded, "the higher-quality record is the base")
        XCTAssertEqual(merged.per100g?[.energyKcal], 418, "base values are never replaced")
        XCTAssertEqual(merged.per100g?[.fiber], 7.27, "gaps are filled from the other source")
        XCTAssertEqual(merged.fieldSources["fiber"], .openFoodFacts)
        XCTAssertEqual(merged.fieldSources["energyKcal"], .usdaBranded)
        XCTAssertEqual(merged.allergens, [.milk, .gluten], "allergens are unioned")
        XCTAssertEqual(merged.traces, [.soy])
        XCTAssertFalse(merged.flags.contains(.sourcesDisagree(.energyKcal)), "418 vs 420 is agreement")
    }

    func testMergeReportsMaterialDisagreement() throws {
        let a = record(.usdaBranded, per100g: NutrientSet([.energyKcal: 400, .protein: 5, .carbohydrate: 60, .fat: 12]))
        let b = record(.openFoodFacts, per100g: NutrientSet([.energyKcal: 250, .protein: 5, .carbohydrate: 60, .fat: 12]))
        let merged = try XCTUnwrap(FoodMerger.merge([a, b]))
        XCTAssertTrue(merged.flags.contains(.sourcesDisagree(.energyKcal)))
        XCTAssertFalse(merged.flags.contains(.sourcesDisagree(.protein)))
        XCTAssertEqual(merged.per100g?[.energyKcal], 400)
        XCTAssertNil(FoodMerger.merge([]))
    }

    func testMergeNeverMixesBases() throws {
        let perGram = record(.usdaBranded, per100g: NutrientSet([.energyKcal: 418, .protein: 5.45, .carbohydrate: 67.27, .fat: 14.55]))
        var perMl = record(.openFoodFacts, per100g: nil)
        perMl.per100ml = NutrientSet([.energyKcal: 42, .fiber: 1])
        let merged = try XCTUnwrap(FoodMerger.merge([perGram, perMl]))
        XCTAssertNil(merged.per100g?[.fiber], "a per-100 ml value must not leak into the per-100 g block")
        XCTAssertEqual(merged.per100ml?[.fiber], 1)
    }

    func testValidatorChecks() {
        var bad = FoodRecord(id: "x", name: "Bad", source: .userCreated, per100g: NutrientSet([.energyKcal: 100, .protein: 60, .carbohydrate: 40, .fat: 10, .sugars: 50, .saturatedFat: 20]))
        bad.flags = NutritionValidator.validate(bad)
        XCTAssertTrue(bad.flags.contains(.macrosExceedMass(grams: 110)))
        XCTAssertTrue(bad.flags.contains(.componentExceedsTotal(part: .sugars, total: .carbohydrate)))
        XCTAssertTrue(bad.flags.contains(.componentExceedsTotal(part: .saturatedFat, total: .fat)))
        XCTAssertTrue(bad.flags.contains { if case .energyMismatch = $0 { return true } else { return false } })

        let negative = FoodRecord(id: "y", name: "Neg", source: .userCreated, perServing: NutrientSet([.energyKcal: 100, .protein: -1, .carbohydrate: 10, .fat: 2]))
        XCTAssertTrue(NutritionValidator.validate(negative).contains(.negativeValue(.protein)))
        XCTAssertTrue(NutritionValidator.validate(negative).contains(.servingOnlyBasis))

        // Low-calorie foods get an absolute tolerance, so rounding noise is not an error.
        let diet = FoodRecord(id: "z", name: "Zero", source: .userCreated, perServing: NutrientSet([.energyKcal: 5, .protein: 0, .carbohydrate: 0.5, .fat: 0]),
                              serving: ServingSize(quantity: 1, unit: "can", text: "1 can"))
        XCTAssertFalse(NutritionValidator.validate(diet).contains { if case .energyMismatch = $0 { return true } else { return false } })
    }

    func testPortionScalingAcrossBases() throws {
        let servingGrams = ServingSize(quantity: 55, unit: "g", grams: 55, text: "55 g")
        var perServingOnly = FoodRecord(id: "a", name: "A", source: .labelScan, perServing: NutrientSet([.energyKcal: 230, .protein: 3, .carbohydrate: 37, .fat: 8]), serving: servingGrams)
        XCTAssertEqual(perServingOnly.nutrients(for: .servings(1.5))?[.energyKcal], 345)
        XCTAssertEqual(perServingOnly.nutrients(for: .grams(110))?[.energyKcal], 460, "scaled through the serving weight")
        XCTAssertNil(perServingOnly.nutrients(for: .milliliters(100)))
        XCTAssertNil(perServingOnly.nutrients(for: .packages(1)), "no package size known")
        XCTAssertNil(perServingOnly.nutrients(for: .servings(-1)))

        perServingOnly.serving = nil
        XCTAssertNil(perServingOnly.nutrients(for: .grams(100)), "no serving weight, no per-100 basis")
        XCTAssertEqual(perServingOnly.nutrients(for: .servings(2))?[.energyKcal], 460)

        let per100Only = FoodRecord(id: "b", name: "B", source: .openFoodFacts, per100g: NutrientSet([.energyKcal: 400]), serving: servingGrams,
                                    packageSize: ServingSize(quantity: 340, unit: "g", grams: 340, text: "340 g"))
        XCTAssertEqual(per100Only.nutrients(for: .servings(1))?[.energyKcal], 220)
        XCTAssertEqual(per100Only.nutrients(for: .packages(0.5))?[.energyKcal], 680)
    }

    func testFoodRecordCodableRoundTrip() throws {
        let original = try found(OpenFoodFacts.map(Data(Self.offCereal.utf8), requested: GTIN("012345678905"), now: Self.now))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FoodRecord.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: JSONValue

    func testJSONParserBasics() throws {
        let value = try JSONValue.parse(Data(#"{"a":[1,2.5,"x",true,null],"b":{"c":"\u00e9\ud83d\ude00\n"},"n":-1.5e2}"#.utf8))
        XCTAssertEqual(value["a"]?[0]?.double, 1)
        XCTAssertEqual(value["a"]?[1]?.double, 2.5)
        XCTAssertEqual(value["a"]?[2]?.string, "x")
        XCTAssertEqual(value["a"]?[3]?.bool, true)
        XCTAssertTrue(value["a"]?[4]?.isNull ?? false)
        XCTAssertEqual(value["b"]?["c"]?.string, "é😀\n")
        XCTAssertEqual(value["n"]?.double, -150)
        XCTAssertNil(value["missing"])
        XCTAssertNil(value["a"]?[99])
    }

    func testJSONLenientAccessors() {
        XCTAssertEqual(JSONValue.string("12,5").double, 12.5)
        XCTAssertEqual(JSONValue.string(" 3 ").int, 3)
        XCTAssertEqual(JSONValue.number(3013210000000).string, "3013210000000")
        XCTAssertEqual(JSONValue.number(2.5).string, "2.5")
        XCTAssertNil(JSONValue.string("abc").double)
        XCTAssertNil(JSONValue.number(2.5).int)
        XCTAssertEqual(JSONValue.string("true").bool, true)
        XCTAssertEqual(JSONValue.array([.string("a"), .number(1), .null]).strings, ["a", "1"])
    }

    func testJSONParserRejectsGarbage() {
        for bad in ["", "{", "[1,", "{\"a\"}", "{\"a\":1,}", "nul", "\"abc", "[1 2]", "{} trailing", "\"\\ud83d\"", "\"\\q\""] {
            XCTAssertThrowsError(try JSONValue.parse(Data(bad.utf8)), bad)
        }
        let deep = String(repeating: "[", count: 100) + String(repeating: "]", count: 100)
        XCTAssertThrowsError(try JSONValue.parse(Data(deep.utf8)))
        XCTAssertNoThrow(try JSONValue.parse(Data([0xEF, 0xBB, 0xBF] + Array("{}".utf8))), "byte order mark is skipped")
    }
}

private extension MappingOutcome {
    var qualityScore: Double {
        if case let .found(record) = self { return FoodQuality.score(record) }
        return 0
    }
}
