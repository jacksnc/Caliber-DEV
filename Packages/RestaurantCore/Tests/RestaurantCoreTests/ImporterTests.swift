import XCTest
import FoodCore
@testable import RestaurantCore

final class CSVTests: XCTestCase {
    func testQuotesCommasAndEmbeddedNewlines() throws {
        let rows = try CSV.parse("a,b,c\n\"x,1\",\"he said \"\"hi\"\"\",\"line1\nline2\"\n")
        XCTAssertEqual(rows, [["a", "b", "c"], ["x,1", "he said \"hi\"", "line1\nline2"]])
    }

    func testLineEndingsBOMAndBlankLines() throws {
        XCTAssertEqual(try CSV.parse("\u{FEFF}a,b\r\n1,2\r\n\r\n3,4"), [["a", "b"], ["1", "2"], ["3", "4"]])
        XCTAssertEqual(try CSV.parse("a\rb\rc"), [["a"], ["b"], ["c"]])
        XCTAssertEqual(try CSV.parse(""), [])
        XCTAssertEqual(try CSV.parse("\n\n"), [])
    }

    func testEmptyFieldsAndTrailingComma() throws {
        XCTAssertEqual(try CSV.parse("a,,c,\n,,\n"), [["a", "", "c", ""], ["", "", ""]])
        XCTAssertEqual(try CSV.parse("\"\",x"), [["", "x"]])
    }

    func testUnterminatedQuoteThrows() {
        XCTAssertThrowsError(try CSV.parse("a,\"b\n1,2")) { error in
            XCTAssertEqual(error as? CSVError, .unterminatedQuote(row: 1))
        }
    }

    func testStrayQuoteInsideUnquotedFieldIsKept() throws {
        XCTAssertEqual(try CSV.parse("5\" pizza,1"), [["5\" pizza", "1"]])
    }
}

final class SlugAndLicenseTests: XCTestCase {
    func testSlugs() {
        XCTAssertEqual(Slug.make("Burger Barn"), "burger-barn")
        XCTAssertEqual(Slug.make("Crème Brûlée & Fries!"), "creme-brulee-and-fries")
        XCTAssertEqual(Slug.make("  Chips   and   Guac  "), "chips-and-guac")
        XCTAssertEqual(Slug.make("Mc'Allister's"), "mcallisters")
        XCTAssertEqual(Slug.make("2% Milk"), "2-milk")
        XCTAssertEqual(Slug.make("日本"), "")
    }

    func testLicenseParsing() {
        XCTAssertEqual(LicenseTag(parsing: "CC0"), .cc0)
        XCTAssertEqual(LicenseTag(parsing: "CC-BY"), .ccBy)
        XCTAssertEqual(LicenseTag(parsing: "cc by-sa 4.0"), .ccBySa)
        XCTAssertEqual(LicenseTag(parsing: "ODbL"), .odbl)
        XCTAssertEqual(LicenseTag(parsing: "Public Domain"), .publicDomain)
        XCTAssertEqual(LicenseTag(parsing: "permission granted"), .permissionGranted)
        XCTAssertEqual(LicenseTag(parsing: "all rights reserved"), .unknown)
        XCTAssertEqual(LicenseTag(parsing: ""), .unknown)
        XCTAssertFalse(LicenseTag.unknown.allowsBundling)
        XCTAssertTrue(LicenseTag.odbl.isShareAlike)
        XCTAssertTrue(LicenseTag.ccBy.requiresAttribution)
        XCTAssertFalse(LicenseTag.cc0.requiresAttribution)
    }
}

final class ImporterTests: XCTestCase {
    func testFixtureLibraryImportsCleanly() throws {
        let report = LibraryImporter.importMenu(csv: Fixtures.menuCSV, modifiersCSV: Fixtures.modifiersCSV)
        XCTAssertFalse(report.hasErrors, "\(report.issues)")
        XCTAssertEqual(report.issues.filter { $0.severity == .warning }, [], "fixture numbers are internally consistent")
        XCTAssertEqual(report.rowsRead, 20)
        XCTAssertEqual(report.rowsImported, 20)
        XCTAssertEqual(report.restaurants.map(\.id), ["burger-barn", "taco-tangent", "bean-there-coffee"])
        XCTAssertEqual(report.restaurants.map(\.category), [.burgers, .mexican, .coffee])
        XCTAssertEqual(report.restaurants.map(\.region), ["US", "US", "US"])
    }

    func testItemsVariantsAndFields() throws {
        let barn = try XCTUnwrap(Fixtures.library().restaurant(id: "burger-barn"))
        XCTAssertEqual(barn.sections, ["Burgers", "Chicken", "Sides", "Drinks"])
        XCTAssertEqual(barn.items.count, 8, "size rows collapse into one item")

        let burger = try XCTUnwrap(barn.item(id: "burger-barn/classic-barn-burger"))
        XCTAssertEqual(burger.nutrients.calories, 540)
        XCTAssertEqual(burger.nutrients[.sodium], 1050)
        XCTAssertEqual(burger.servingGrams, 220)
        XCTAssertEqual(burger.servingDescription, "1 burger")
        XCTAssertEqual(burger.allergens, [.milk, .wheat, .egg])
        XCTAssertEqual(burger.aliases, ["barn burger", "classic"])
        XCTAssertEqual(burger.modifierGroupIDs, ["burger-barn/burger-toppings", "burger-barn/burger-sauce"])

        let fries = try XCTUnwrap(barn.item(id: "burger-barn/fries"))
        XCTAssertEqual(fries.variants.map(\.id), ["small", "medium", "large"])
        XCTAssertEqual(fries.nutrients.calories, 230, "the first size row is the listed build")
        XCTAssertEqual(fries.baseNutrients(variantID: "large").calories, 450)
        XCTAssertEqual(fries.baseNutrients(variantID: nil).calories, 230)
        XCTAssertEqual(fries.baseNutrients(variantID: "nonexistent").calories, 230)
        XCTAssertEqual(fries.dietTags, [.vegan])

        let veggie = try XCTUnwrap(barn.item(id: "burger-barn/garden-veggie-burger"))
        XCTAssertEqual(veggie.dietTags, [.vegetarian])
    }

    func testProvenanceIsCarriedAndDemoDataIsMarked() throws {
        let barn = try XCTUnwrap(Fixtures.library().restaurant(id: "burger-barn"))
        XCTAssertEqual(barn.provenance.kind, .demoFictional)
        XCTAssertTrue(barn.provenance.isDemo)
        XCTAssertEqual(barn.provenance.license, .cc0)
        XCTAssertEqual(barn.provenance.asOf, "2026-10")
        XCTAssertEqual(barn.provenance.sourceName, "Helios fictional demo menus")
        let item = try XCTUnwrap(barn.items.first)
        XCTAssertEqual(barn.effectiveProvenance(for: item), barn.provenance)
    }

    func testModifierGroupsAndOptions() throws {
        let barn = try XCTUnwrap(Fixtures.library().restaurant(id: "burger-barn"))
        let toppings = try XCTUnwrap(barn.group(id: "burger-barn/burger-toppings"))
        XCTAssertEqual(toppings.rule, .multiple(max: nil))
        XCTAssertEqual(toppings.options.map(\.name), ["Cheese", "Lettuce and Tomato", "Bacon", "Fried Egg"])
        XCTAssertEqual(toppings.defaultOptionIDs, ["burger-barn/burger-toppings/cheese", "burger-barn/burger-toppings/lettuce-and-tomato"])
        XCTAssertEqual(toppings.options[0].delta.calories, 80)

        let sauce = try XCTUnwrap(barn.group(id: "burger-barn/burger-sauce"))
        XCTAssertEqual(sauce.rule, .single(required: false))

        let bowl = try XCTUnwrap(Fixtures.library().restaurant(id: "taco-tangent")?.group(id: "taco-tangent/bowl-protein"))
        XCTAssertEqual(bowl.rule, .single(required: true))
        let milk = try XCTUnwrap(Fixtures.library().restaurant(id: "bean-there-coffee")?.group(id: "bean-there-coffee/milk"))
        XCTAssertEqual(milk.options.map(\.name), ["2% Milk", "Nonfat Milk", "Whole Milk", "Oat Milk"])
        XCTAssertEqual(milk.options[0].id, "bean-there-coffee/milk/2-milk")
    }

    func testRuleParsing() {
        XCTAssertEqual(LibraryImporter.parseRule("multiple_max2"), .multiple(max: 2))
        XCTAssertEqual(LibraryImporter.parseRule("Max 3"), .multiple(max: 3))
        XCTAssertEqual(LibraryImporter.parseRule("single required"), .single(required: true))
        XCTAssertEqual(LibraryImporter.parseRule(""), .multiple(max: nil))
    }

    // MARK: rejections

    private let header = "restaurant,section,item,calories,protein_g,carbs_g,fat_g,sodium_mg,license,source_name,as_of"

    private func report(_ rows: String..., policy: ImportPolicy = ImportPolicy()) -> ImportReport {
        LibraryImporter.importMenu(csv: ([header] + rows).joined(separator: "\n"), policy: policy)
    }

    func testMissingRequiredColumns() {
        let noCalories = LibraryImporter.importMenu(csv: "restaurant,item\nA,B")
        XCTAssertTrue(noCalories.hasErrors)
        XCTAssertEqual(noCalories.issues(.missingColumn).count, 1)
        XCTAssertTrue(noCalories.restaurants.isEmpty)
        XCTAssertTrue(LibraryImporter.importMenu(csv: "").hasErrors)
        XCTAssertTrue(LibraryImporter.importMenu(csv: "a,b\n\"unterminated").hasErrors)
    }

    func testBadRowsAreSkippedAndReported() {
        let result = report(
            "Cafe,Food,Good Item,300,10,30,15,500,cc0,src,2026-10",
            "Cafe,Food,Negative,-5,10,30,15,500,cc0,src,2026-10",
            "Cafe,Food,Letters,abc,10,30,15,500,cc0,src,2026-10",
            "Cafe,Food,,300,10,30,15,500,cc0,src,2026-10",
            "Cafe,Food,No Calories,,10,30,15,500,cc0,src,2026-10",
            "Cafe,Food,Good Item,310,10,30,15,500,cc0,src,2026-10",
            "Cafe,Food,Extra,300,10,30,15,500,cc0,src,2026-10,surplus"
        )
        XCTAssertEqual(result.rowsRead, 7)
        XCTAssertEqual(result.rowsImported, 1)
        XCTAssertEqual(result.restaurants.first?.items.map(\.name), ["Good Item"])
        XCTAssertEqual(result.issues(.negativeValue).first?.row, 3)
        XCTAssertEqual(result.issues(.invalidNumber).first?.row, 4)
        XCTAssertEqual(result.issues(.missingValue).map(\.row), [5, 6])
        XCTAssertEqual(result.issues(.duplicateItem).first?.row, 7)
        XCTAssertEqual(result.issues(.rowShape).first?.row, 8)
        XCTAssertEqual(result.count(.error), 6)
    }

    func testUnknownLicenseIsRefusedByDefault() {
        let rows = ["Cafe,Food,Scraped Item,300,10,30,15,500,,scraped site,2026-10", "Cafe,Food,Other,300,10,30,15,500,all rights reserved,site,2026-10"]
        let strict = report(rows[0], rows[1])
        XCTAssertEqual(strict.issues(.licenseUnknown).count, 2)
        XCTAssertTrue(strict.restaurants.isEmpty, "nothing of unknown terms may be bundled")

        var lenient = ImportPolicy()
        lenient.requireKnownLicense = false
        let allowed = report(rows[0], policy: lenient)
        XCTAssertEqual(allowed.restaurants.first?.items.first?.name, "Scraped Item")
        XCTAssertEqual(allowed.restaurants.first?.provenance.license, .unknown)
    }

    func testDefaultProvenanceFillsMissingSourceColumns() {
        var policy = ImportPolicy()
        policy.defaultProvenance = Provenance(kind: .userContributed, sourceName: "My notes", license: .userOwned, asOf: "2026-10-01")
        policy.defaultRegion = "CA"
        let result = LibraryImporter.importMenu(csv: "restaurant,item,calories\nHome Cafe,Soup,200", policy: policy)
        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(result.restaurants.first?.provenance.kind, .userContributed)
        XCTAssertEqual(result.restaurants.first?.provenance.license, .userOwned)
        XCTAssertEqual(result.restaurants.first?.region, "CA")
        XCTAssertEqual(result.restaurants.first?.items.first?.section, "Menu")
    }

    func testNumberFormats() {
        XCTAssertEqual(LibraryImporter.parseNumber("1,050"), .value(1050))
        XCTAssertEqual(LibraryImporter.parseNumber("1,234.5"), .value(1234.5))
        XCTAssertEqual(LibraryImporter.parseNumber("12,5"), .invalid, "a decimal comma is ambiguous")
        XCTAssertEqual(LibraryImporter.parseNumber("8g"), .value(8))
        XCTAssertEqual(LibraryImporter.parseNumber("160 mg"), .value(160))
        XCTAssertEqual(LibraryImporter.parseNumber("230 kcal"), .value(230))
        XCTAssertEqual(LibraryImporter.parseNumber("<1"), .lessThan(1))
        XCTAssertEqual(LibraryImporter.parseNumber(" "), .missing)
        XCTAssertEqual(LibraryImporter.parseNumber("N/A"), .missing)
        XCTAssertEqual(LibraryImporter.parseNumber("-"), .missing)
        XCTAssertEqual(LibraryImporter.parseNumber("1.2.3"), .invalid)
        XCTAssertEqual(LibraryImporter.parseNumber("1,23"), .invalid)
        XCTAssertEqual(LibraryImporter.parseNumber("nan"), .invalid)
    }

    func testLenientNumberFormatsImport() {
        let result = report("Cafe,Food,Soup,\"1,050\",<1,8g,\"3,5\",160 mg,cc0,src,2026-10")
        XCTAssertEqual(result.count(.error), 1, "\"3,5\" is rejected")
        let ok = report("Cafe,Food,Soup,\"1,050\",<1,8g,3.5,160 mg,cc0,src,2026-10")
        XCTAssertEqual(ok.restaurants.first?.items.first?.nutrients.calories, 1050)
        XCTAssertEqual(ok.restaurants.first?.items.first?.nutrients.proteinG, 0.5)
        XCTAssertEqual(ok.restaurants.first?.items.first?.nutrients[.sodium], 160)
        XCTAssertEqual(ok.issues(.lessThanValue).count, 1)
    }

    // MARK: warnings

    func testSuspiciousNumbersAreWarnedNotRejected() {
        let result = LibraryImporter.importMenu(csv: """
        restaurant,section,item,serving_g,calories,protein_g,carbs_g,fat_g,sat_fat_g,sugars_g,fiber_g,sodium_mg,license
        Cafe,Food,Mismatch,200,900,10,10,10,0,0,0,300,cc0
        Cafe,Food,Salty Slip,200,500,20,40,22,5,5,2,1.05,cc0
        Cafe,Food,Parts,200,300,10,30,5,9,40,2,200,cc0
        Cafe,Food,Heavy,100,500,60,60,30,5,5,2,200,cc0
        Cafe,Food,Huge,500,9000,10,10,10,0,0,0,300,cc0
        """)
        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(result.restaurants.first?.items.count, 5, "warnings keep the row")
        XCTAssertEqual(result.issues(.energyMismatch).map(\.row), [2, 4, 5, 6])
        XCTAssertEqual(result.issues(.implausibleSodium).map(\.row), [3])
        XCTAssertEqual(result.issues(.partsExceedWhole).map(\.row), [4, 4])
        XCTAssertEqual(result.issues(.macrosExceedServing).map(\.row), [5])
        XCTAssertEqual(result.issues(.implausibleCalories).map(\.row), [6])
    }

    func testUnknownTagsAndColumnsAreReported() {
        let result = LibraryImporter.importMenu(csv: """
        restaurant,item,calories,allergens,diet_tags,modifier_groups,mystery,license
        Cafe,Soup,200,milk;kryptonite,vegan;paleo,Toppings,x,cc0
        """)
        XCTAssertEqual(result.issues(.unknownAllergen).count, 1)
        XCTAssertEqual(result.issues(.unknownDietTag).count, 1)
        XCTAssertEqual(result.issues(.unknownModifierGroup).count, 1)
        XCTAssertEqual(result.issues(.unknownColumn).count, 1)
        XCTAssertEqual(result.restaurants.first?.items.first?.allergens, [.milk])
        XCTAssertEqual(result.restaurants.first?.items.first?.dietTags, [.vegan])
    }

    func testSameNameInTwoSectionsGetsDistinctIDs() {
        let result = LibraryImporter.importMenu(csv: """
        restaurant,section,item,calories,license
        Cafe,Sides,Fries,300,cc0
        Cafe,Kids,Fries,150,cc0
        """)
        XCTAssertEqual(result.restaurants.first?.items.map(\.id), ["cafe/fries", "cafe/fries-kids"])
    }

    func testPerRowProvenanceDifferingFromRestaurantIsKeptOnTheItem() throws {
        let result = LibraryImporter.importMenu(csv: """
        restaurant,item,calories,license,source_name,as_of
        Cafe,Soup,200,cc0,Official PDF,2026-09
        Cafe,Salad,150,cc-by,Community sheet,2026-10
        """)
        let cafe = try XCTUnwrap(result.restaurants.first)
        XCTAssertNil(cafe.items[0].provenance)
        XCTAssertEqual(cafe.items[1].provenance?.license, .ccBy)
        XCTAssertEqual(cafe.effectiveProvenance(for: cafe.items[1]).sourceName, "Community sheet")
        XCTAssertEqual(cafe.provenance.sourceName, "Official PDF")
    }

    func testDuplicateModifierOptionAndBadModifierRows() {
        let result = LibraryImporter.importMenu(
            csv: "restaurant,item,calories,license\nCafe,Soup,200,cc0",
            modifiersCSV: """
            restaurant,group,option,calories
            Cafe,Extras,Bacon,70
            Cafe,Extras,Bacon,70
            Cafe,Extras,,10
            Cafe,Extras,Cheese,abc
            """
        )
        XCTAssertEqual(result.issues(.duplicateOption).count, 1)
        XCTAssertEqual(result.issues(.missingValue).count, 1)
        XCTAssertEqual(result.issues(.invalidNumber).count, 1)
    }

    func testLibraryCodableRoundTrip() throws {
        let library = Fixtures.library()
        let data = try JSONEncoder().encode(library)
        XCTAssertEqual(try JSONDecoder().decode(RestaurantLibrary.self, from: data), library)
        XCTAssertEqual(library.itemCount, 15)
        XCTAssertEqual(library.item(id: "taco-tangent/burrito-bowl")?.restaurant.name, "Taco Tangent")
        XCTAssertNil(library.item(id: "nope/nothing"))
    }
}
