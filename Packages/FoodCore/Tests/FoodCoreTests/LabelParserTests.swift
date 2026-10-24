import XCTest
@testable import FoodCore

/// The clean label is the FDA's published sample "Nutrition Facts" panel (public domain); the noisy variants
/// reproduce typical OCR mistakes: units read as digits, letter O for zero, split columns.
final class LabelParserTests: XCTestCase {
    static let clean = """
    Nutrition Facts
    8 servings per container
    Serving size 2/3 cup (55g)
    Amount per serving
    Calories 230
    % Daily Value*
    Total Fat 8g 10%
    Saturated Fat 1g 5%
    Trans Fat 0g
    Cholesterol 0mg 0%
    Sodium 160mg 7%
    Total Carbohydrate 37g 13%
    Dietary Fiber 4g 14%
    Total Sugars 12g
    Includes 10g Added Sugars 20%
    Protein 3g
    Vitamin D 2mcg 10%
    Calcium 260mg 20%
    Iron 8mg 45%
    Potassium 235mg 6%
    * The % Daily Value (DV) tells you how much a nutrient in a serving of food contributes to a daily diet. 2,000 calories a day is used for general nutrition advice.
    """

    func testCleanUSLabel() {
        let label = LabelParser.parse(Self.clean)
        XCTAssertEqual(label.basis, .perServing)
        XCTAssertEqual(label.servingsPerContainer, 8)
        XCTAssertEqual(label.serving?.grams, 55)
        XCTAssertEqual(label.serving?.unit, "cup")
        XCTAssertEqual(label.servingText, "2/3 cup (55g)")

        let expected: [Nutrient: Double] = [
            .energyKcal: 230, .fat: 8, .saturatedFat: 1, .transFat: 0, .cholesterol: 0, .sodium: 160, .carbohydrate: 37,
            .fiber: 4, .sugars: 12, .addedSugars: 10, .protein: 3, .vitaminD: 2, .calcium: 260, .iron: 8, .potassium: 235,
        ]
        for (nutrient, value) in expected {
            XCTAssertEqual(label.readings[nutrient]?.value, value, "\(nutrient)")
            XCTAssertEqual(label.readings[nutrient]?.confidence, .high, "\(nutrient)")
            XCTAssertNil(label.readings[nutrient]?.repair, "\(nutrient)")
        }
        XCTAssertEqual(label.readings.count, expected.count, "the 2,000-calorie footnote must not become a reading")
        XCTAssertEqual(label.readings[.fat]?.percentDailyValue, 10)
        XCTAssertEqual(label.warnings, [])
        XCTAssertEqual(label.needsConfirmation, [])
        XCTAssertTrue(label.isUsable)
        XCTAssertEqual(label.nutrientSet.atwaterKcal ?? 0, 232, accuracy: 1e-9)
    }

    func testNoisyOCRIsRepairedUsingDailyValues() {
        let noisy = Self.clean
            .replacingOccurrences(of: "Total Fat 8g 10%", with: "Total Fat 89 10%")
            .replacingOccurrences(of: "Trans Fat 0g", with: "Trans Fat Og")
            .replacingOccurrences(of: "Cholesterol 0mg 0%", with: "Cholesterol Omg 0%")
            .replacingOccurrences(of: "Sodium 160mg 7%", with: "Sodium 160m9 7%")
            .replacingOccurrences(of: "Total Carbohydrate 37g 13%", with: "Total Carbohydrate 379 13%")
        let label = LabelParser.parse(noisy)

        XCTAssertEqual(label.readings[.fat]?.value, 8)
        XCTAssertEqual(label.readings[.fat]?.repair, .trailingUnitDigit(original: 89))
        XCTAssertEqual(label.readings[.fat]?.confidence, .medium)
        XCTAssertEqual(label.readings[.carbohydrate]?.value, 37)
        XCTAssertEqual(label.readings[.carbohydrate]?.repair, .trailingUnitDigit(original: 379))
        XCTAssertEqual(label.readings[.transFat]?.value, 0)
        XCTAssertEqual(label.readings[.cholesterol]?.value, 0)
        XCTAssertEqual(label.readings[.sodium]?.value, 160)
        XCTAssertEqual(label.readings[.sodium]?.confidence, .high, "an explicit mg unit read through OCR noise needs no flag")
        XCTAssertEqual(label.needsConfirmation, [.carbohydrate, .fat], "only the repaired rows are highlighted")
        XCTAssertEqual(label.warnings, [])
    }

    func testLostDecimalPointIsRepaired() {
        // Total fat 4.5 g at 6% DV (78 g reference gives 4.7 g) read as "45".
        let label = LabelParser.parse("Calories 70\nTotal Fat 45 6%\nProtein 3g\nTotal Carbohydrate 5g")
        XCTAssertEqual(label.readings[.fat]?.value, 4.5)
        XCTAssertEqual(label.readings[.fat]?.repair, .decimalPoint(original: 45))
        // Whole-number amounts prefer the dropped-unit reading: "89" is 8 g, not 8.9 g.
        let whole = LabelParser.parse("Calories 100\nTotal Fat 89 10%\nProtein 3g\nTotal Carbohydrate 5g")
        XCTAssertEqual(whole.readings[.fat]?.value, 8)
        // Milligram amounts are never given a decimal point.
        let sodium = LabelParser.parse("Calories 100\nSodium 1609 7%\nProtein 3g\nTotal Fat 1g\nTotal Carbohydrate 5g")
        XCTAssertEqual(sodium.readings[.sodium]?.value, 160)
        XCTAssertEqual(sodium.readings[.sodium]?.repair, .trailingUnitDigit(original: 1609))
    }

    func testUnresolvableMismatchIsFlaggedNotInvented() {
        // 40 g fat at 10% DV cannot be fixed by dropping a digit or shifting the point (4 g would be 5%).
        let label = LabelParser.parse("Calories 360\nTotal Fat 40g 10%\nTotal Carbohydrate 20g\nProtein 5g")
        XCTAssertEqual(label.readings[.fat]?.value, 40)
        XCTAssertEqual(label.readings[.fat]?.confidence, .low)
        XCTAssertTrue(label.warnings.contains(.percentDailyValueMismatch(.fat, parsed: 40)))
        XCTAssertEqual(label.needsConfirmation, [.fat])
    }

    func testValuesOnSeparateLines() {
        let label = LabelParser.parse("Calories\n230\nTotal Fat\n8g\n10%\nProtein\n3g\nTotal Carbohydrate\n37g\n13%")
        XCTAssertEqual(label.readings[.energyKcal]?.value, 230)
        XCTAssertEqual(label.readings[.fat]?.value, 8)
        XCTAssertEqual(label.readings[.fat]?.percentDailyValue, 10, "a %DV alone on the next line is attached")
        XCTAssertEqual(label.readings[.protein]?.value, 3)
        XCTAssertEqual(label.readings[.carbohydrate]?.value, 37)
        XCTAssertTrue(label.isUsable)
    }

    func testSeparatedUnitsAndPercentSigns() {
        let label = LabelParser.parse("Calories 230\nTotal Fat 8 g 10 %\nSodium 160 mg 7 %\nProtein 3 g\nTotal Carbohydrate 37 g 13 %")
        XCTAssertEqual(label.readings[.fat]?.value, 8)
        XCTAssertEqual(label.readings[.fat]?.percentDailyValue, 10)
        XCTAssertEqual(label.readings[.sodium]?.value, 160)
    }

    func testOldFormatCaloriesFromFatIsIgnored() {
        let label = LabelParser.parse("Calories 230 Calories from Fat 72\nTotal Fat 8g 12%\nProtein 3g\nTotal Carbohydrate 37g 12%")
        XCTAssertEqual(label.readings[.energyKcal]?.value, 230)
        XCTAssertEqual(label.readings[.fat]?.value, 8)
        XCTAssertEqual(label.readings[.fat]?.confidence, .high, "8 g at 12% fits the pre-2020 65 g reference too")
    }

    func testLessThanValues() {
        let label = LabelParser.parse("Calories 5\nTotal Fat 0g\nTotal Carbohydrate 1g\nTotal Sugars <1g\nProtein Less than 1g")
        XCTAssertEqual(label.readings[.sugars]?.value, 0.5)
        XCTAssertEqual(label.readings[.sugars]?.wasLessThan, true)
        XCTAssertEqual(label.readings[.sugars]?.confidence, .medium)
        XCTAssertEqual(label.readings[.protein]?.value, 0.5)
        XCTAssertEqual(label.readings[.protein]?.wasLessThan, true)
    }

    func testUnitConversionToCanonical() {
        let label = LabelParser.parse("Calories 100\nSodium 0.16g\nProtein 3g\nTotal Fat 1g\nTotal Carbohydrate 20g\nVitamin D 2µg")
        XCTAssertEqual(label.readings[.sodium]?.value, 160)
        XCTAssertEqual(label.readings[.vitaminD]?.value, 2)
    }

    func testMissingUnitIsAssumedButConfirmedByDailyValue() {
        let label = LabelParser.parse("Calories 100\nProtein 3\nTotal Fat 8 10%\nTotal Carbohydrate 20")
        XCTAssertEqual(label.readings[.protein]?.value, 3)
        XCTAssertEqual(label.readings[.protein]?.confidence, .medium, "no unit and no %DV to confirm it")
        XCTAssertEqual(label.readings[.fat]?.confidence, .high, "%DV agrees with the bare number")
    }

    func testEuropeanPer100gTable() {
        let text = """
        Nutrition Information
        Typical values per 100g
        Energy 1046kJ / 250kcal
        Fat 12g
        of which saturates 3.0g
        Carbohydrate 30g
        of which sugars 5.0g
        Fibre 2.5g
        Protein 6.0g
        Salt 1.2g
        """
        let label = LabelParser.parse(text)
        XCTAssertEqual(label.basis, .per100g)
        XCTAssertEqual(label.readings[.energyKcal]?.value, 250)
        XCTAssertEqual(label.readings[.fat]?.value, 12)
        XCTAssertEqual(label.readings[.saturatedFat]?.value, 3)
        XCTAssertEqual(label.readings[.carbohydrate]?.value, 30)
        XCTAssertEqual(label.readings[.sugars]?.value, 5)
        XCTAssertEqual(label.readings[.fiber]?.value, 2.5)
        XCTAssertEqual(label.readings[.protein]?.value, 6)
        XCTAssertEqual(label.readings[.sodium]?.value, 480, "1.2 g salt = 480 mg sodium")
        XCTAssertEqual(label.readings[.sodium]?.confidence, .medium)
        XCTAssertEqual(label.warnings, [])
    }

    func testEuropeanEnergyInKilojoulesOnlyAndPer100ml() {
        let label = LabelParser.parse("Per 100 ml\nEnergy 180kJ\nFat 0g\nCarbohydrate 10.6g\nProtein 0g")
        XCTAssertEqual(label.basis, .per100ml)
        XCTAssertEqual(label.readings[.energyKcal]?.value ?? 0, 43.021, accuracy: 1e-3)
    }

    func testAtwaterMismatchWarns() {
        let label = LabelParser.parse("Calories 900\nTotal Fat 8g 10%\nTotal Carbohydrate 37g 13%\nProtein 3g")
        XCTAssertTrue(label.warnings.contains(.energyMismatch(declaredKcal: 900, atwaterKcal: 232)))
        XCTAssertEqual(label.readings[.energyKcal]?.confidence, .medium)
    }

    func testIncompleteLabelWarnings() {
        let onlyCalories = LabelParser.parse("Calories 230")
        XCTAssertFalse(onlyCalories.isUsable)
        XCTAssertEqual(onlyCalories.warnings, [.missingMacros([.protein, .carbohydrate, .fat])])

        let empty = LabelParser.parse("")
        XCTAssertTrue(empty.readings.isEmpty)
        XCTAssertEqual(empty.warnings, [.missingCalories, .missingMacros([.protein, .carbohydrate, .fat])])
    }

    func testFirstOccurrenceWinsForDualColumnLabels() {
        let label = LabelParser.parse("Calories 230 460\nTotal Fat 8g 12g\nProtein 3g 6g\nTotal Carbohydrate 37g 74g")
        XCTAssertEqual(label.readings[.energyKcal]?.value, 230, "per-serving column comes first")
        XCTAssertEqual(label.readings[.fat]?.value, 8)
    }

    // MARK: pieces

    func testTokenizer() {
        let tokens = LabelParser.tokens(in: "Includes 10g Added Sugars 20%")
        XCTAssertEqual(tokens.map(\.value), [10, 20])
        XCTAssertEqual(tokens.map(\.unit), ["g", nil])
        XCTAssertEqual(tokens.map(\.isPercent), [false, true])
        XCTAssertEqual(LabelParser.tokens(in: "Sodium 2,300mg").first?.value, 2300)
        XCTAssertEqual(LabelParser.tokens(in: "Fat 1,5g").first?.value, 1.5)
        XCTAssertEqual(LabelParser.tokens(in: "8g10%").map(\.value), [8, 10])
        XCTAssertEqual(LabelParser.tokens(in: "Fat 1O g").first?.value, 10)
    }

    func testConsistencyCheckAcceptsBothDailyValueGenerations() {
        let fat = LabelParser.usSpecs.first { $0.nutrient == .fat }!
        let sodium = LabelParser.usSpecs.first { $0.nutrient == .sodium }!
        XCTAssertTrue(LabelParser.consistent(8, percent: 10, spec: fat))
        XCTAssertTrue(LabelParser.consistent(6.5, percent: 10, spec: fat), "65 g reference")
        XCTAssertFalse(LabelParser.consistent(89, percent: 10, spec: fat))
        XCTAssertTrue(LabelParser.consistent(160, percent: 7, spec: sodium))
        XCTAssertTrue(LabelParser.consistent(0, percent: 0, spec: sodium))
        XCTAssertFalse(LabelParser.consistent(1600, percent: 7, spec: sodium))
    }
}

final class TextRowAssemblerTests: XCTestCase {
    private func fragment(_ text: String, x: Double, y: Double, h: Double = 0.02) -> TextFragment {
        TextFragment(text: text, minX: x, midY: y, height: h)
    }

    func testColumnsAreJoinedIntoRowsTopToBottom() {
        let rows = TextRowAssembler.rows(from: [
            fragment("10%", x: 0.80, y: 0.795),
            fragment("Total Fat", x: 0.10, y: 0.800),
            fragment("8g", x: 0.55, y: 0.806),
            fragment("Protein", x: 0.10, y: 0.700),
            fragment("3g", x: 0.55, y: 0.702),
            fragment("Calories", x: 0.10, y: 0.900),
            fragment("230", x: 0.60, y: 0.898, h: 0.04),
        ])
        XCTAssertEqual(rows, ["Calories 230", "Total Fat 8g 10%", "Protein 3g"])
    }

    func testDistinctRowsStaySeparateAndBlankFragmentsAreDropped() {
        let rows = TextRowAssembler.rows(from: [
            fragment("A", x: 0.1, y: 0.50),
            fragment("   ", x: 0.3, y: 0.50),
            fragment("B", x: 0.1, y: 0.47),
        ])
        XCTAssertEqual(rows, ["A", "B"])
        XCTAssertEqual(TextRowAssembler.rows(from: []), [])
    }

    func testAssembledRowsFeedTheLabelParser() {
        let fragments = [
            fragment("Calories", x: 0.1, y: 0.90), fragment("230", x: 0.7, y: 0.90),
            fragment("Total Fat", x: 0.1, y: 0.85), fragment("8g", x: 0.5, y: 0.85), fragment("10%", x: 0.8, y: 0.85),
            fragment("Total Carbohydrate", x: 0.1, y: 0.80), fragment("37g", x: 0.5, y: 0.80), fragment("13%", x: 0.8, y: 0.80),
            fragment("Protein", x: 0.1, y: 0.75), fragment("3g", x: 0.5, y: 0.75),
        ]
        let label = LabelParser.parse(lines: TextRowAssembler.rows(from: fragments))
        XCTAssertEqual(label.readings[.energyKcal]?.value, 230)
        XCTAssertEqual(label.readings[.fat]?.value, 8)
        XCTAssertEqual(label.readings[.carbohydrate]?.value, 37)
        XCTAssertTrue(label.isUsable)
        XCTAssertEqual(label.warnings, [])
    }
}
