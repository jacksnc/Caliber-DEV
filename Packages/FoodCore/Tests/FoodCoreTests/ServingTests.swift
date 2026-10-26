import XCTest
@testable import FoodCore

final class ServingTests: XCTestCase {
    private func serving(_ text: String, file: StaticString = #filePath, line: UInt = #line) throws -> ServingSize {
        try XCTUnwrap(ServingParser.parse(text), "could not parse \(text)", file: file, line: line)
    }

    func testPlainMetric() throws {
        for text in ["30 g", "30g", "30 grams", "30 G"] {
            let s = try serving(text)
            XCTAssertEqual(s.quantity, 30, text)
            XCTAssertEqual(s.unit, "g")
            XCTAssertEqual(s.grams, 30)
            XCTAssertNil(s.milliliters)
        }
        XCTAssertEqual(try serving("250 ml").milliliters, 250)
        XCTAssertEqual(try serving("1.5 l").milliliters, 1500)
        XCTAssertEqual(try serving("2 kg").grams, 2000)
        XCTAssertEqual(try serving("500 mg").grams ?? 0, 0.5, accuracy: 1e-9)
    }

    func testHouseholdMeasureWithMetricParenthesis() throws {
        let cup = try serving("1 cup (240ml)")
        XCTAssertEqual(cup.unit, "cup")
        XCTAssertEqual(cup.milliliters, 240)
        XCTAssertNil(cup.grams)

        let twoThirds = try serving("2/3 cup (55g)")
        XCTAssertEqual(twoThirds.quantity, 0.666667, accuracy: 1e-6)
        XCTAssertEqual(twoThirds.grams, 55)
        XCTAssertEqual(twoThirds.milliliters ?? 0, 160, accuracy: 1e-4)

        let tbsp = try serving("2 tbsp (32g)")
        XCTAssertEqual(tbsp.unit, "tbsp")
        XCTAssertEqual(tbsp.grams, 32)
        XCTAssertEqual(tbsp.milliliters, 30)

        let slice = try serving("1 slice (28 g)")
        XCTAssertEqual(slice.unit, "slice")
        XCTAssertEqual(slice.grams, 28)

        let chips = try serving("about 12 chips (28 g)")
        XCTAssertEqual(chips.quantity, 12)
        XCTAssertEqual(chips.unit, "chips")
        XCTAssertEqual(chips.grams, 28)
    }

    func testMixedNumbersAndVulgarFractions() throws {
        XCTAssertEqual(try serving("1 1/2 cups (360 mL)").quantity, 1.5)
        XCTAssertEqual(try serving("1 1/2 cups (360 mL)").milliliters, 360)
        XCTAssertEqual(try serving("1½ cups").quantity, 1.5)
        XCTAssertEqual(try serving("½ cup").milliliters, 120)
        XCTAssertEqual(try serving("¾ cup").milliliters, 180)
        XCTAssertEqual(try serving("1 2/3 cup").quantity, 1.666667, accuracy: 1e-6)
        XCTAssertEqual(try serving("1-2 tbsp").quantity, 1.5)
    }

    func testImperialUnits() throws {
        XCTAssertEqual(try serving("1 oz").grams ?? 0, 28.349523, accuracy: 1e-4)
        XCTAssertEqual(try serving("1 lb").grams ?? 0, 453.59237, accuracy: 1e-6)
        XCTAssertEqual(try serving("8 fl oz").milliliters ?? 0, 236.588, accuracy: 1e-3)
        XCTAssertEqual(try serving("8 fl. oz. (240 mL)").milliliters, 240)
        XCTAssertEqual(try serving("8 fl oz (240 mL)").unit, "fl oz")
    }

    func testParentheticalMetricWinsOverRoundedImperial() throws {
        XCTAssertEqual(try serving("1 oz (28g)").grams, 28)
        XCTAssertEqual(try serving("28g (1 oz)").grams, 28)
        XCTAssertEqual(try serving("28g (1 oz)").unit, "g")
        XCTAssertEqual(try serving("1 cup (227 g)").grams, 227)
        XCTAssertEqual(try serving("1 cup (227 g)").milliliters, 240)
    }

    func testDecimalCommasAndThousands() throws {
        XCTAssertEqual(try serving("1,5 dl").milliliters, 150)
        XCTAssertEqual(try serving("28,35 g").grams, 28.35)
        XCTAssertEqual(try serving("0,5 l").milliliters, 500)
        XCTAssertEqual(try serving("1,000 g").grams, 1000)
        XCTAssertEqual(try serving("1.000 g").grams, 1, "dot is always a decimal point")
    }

    func testLabelPrefixesAndNoise() throws {
        XCTAssertEqual(try serving("Serving size: 30 g").grams, 30)
        XCTAssertEqual(try serving("per 100g").grams, 100)
        XCTAssertEqual(try serving("~30 g").grams, 30)
        XCTAssertEqual(try serving("approx. 45 g").grams, 45)
    }

    func testLeadingUnitInsideLongerPhrase() throws {
        let cooked = try serving("1 cup cooked (140 g)")
        XCTAssertEqual(cooked.unit, "cup")
        XCTAssertEqual(cooked.grams, 140)
        XCTAssertEqual(cooked.milliliters, 240)
    }

    func testServingWithoutQuantity() throws {
        let metricOnly = try serving("(55g)")
        XCTAssertEqual(metricOnly.quantity, 1)
        XCTAssertEqual(metricOnly.unit, "serving")
        XCTAssertEqual(metricOnly.grams, 55)
        XCTAssertEqual(try serving("1 serving (100 g)").unit, "serving")
        XCTAssertEqual(try serving("1 can (355 ml)").milliliters, 355)
    }

    func testUnparseableText() {
        XCTAssertNil(ServingParser.parse(""))
        XCTAssertNil(ServingParser.parse("abc"))
        XCTAssertNil(ServingParser.parse("box of 6"))
    }

    func testPackageSizes() throws {
        XCTAssertEqual(try XCTUnwrap(ServingParser.parsePackage("500 g")).grams, 500)
        let sixPack = try XCTUnwrap(ServingParser.parsePackage("6 x 330 ml"))
        XCTAssertEqual(sixPack.milliliters, 1980)
        XCTAssertEqual(sixPack.count, 6)
        XCTAssertEqual(try XCTUnwrap(ServingParser.parsePackage("4 x 125g")).grams, 500)
        XCTAssertEqual(try XCTUnwrap(ServingParser.parsePackage("12×355ml")).milliliters, 4260)
        XCTAssertNil(try XCTUnwrap(ServingParser.parsePackage("1.5 l")).count)
        XCTAssertNil(ServingParser.parsePackage("box of 6"))
    }

    func testGramsEstimateUsesDensityOnlyWhenNeeded() throws {
        XCTAssertEqual(try serving("30 g").gramsEstimate(densityGramsPerMilliliter: 2), 30)
        XCTAssertEqual(try serving("240 ml").gramsEstimate(densityGramsPerMilliliter: 1.03) ?? 0, 247.2, accuracy: 1e-9)
        XCTAssertNil(try serving("240 ml").gramsEstimate())
    }
}
