import XCTest
@testable import StackCore

// These are arithmetic tests of the calculator, not dosing guidance.
final class ReconstitutionTests: XCTestCase {
    private func d(_ text: String) -> Decimal {
        guard let value = Decimal(string: text) else { fatalError("bad decimal \(text)") }
        return value
    }

    func testVectorFiveMilligramsInTwoMillilitres() throws {
        let r = try ReconstitutionCalculator.calculate(
            vial: Amount(d("5"), .mg), diluentML: d("2"), dose: Amount(d("0.25"), .mg), syringe: .u100Full)
        XCTAssertEqual(r.concentration, d("2.5"))
        XCTAssertEqual(r.drawML, d("0.1"))
        XCTAssertEqual(r.syringeUnits, d("10"))
        XCTAssertEqual(r.dosesPerVial, d("20"))
        XCTAssertEqual(r.fullDosesPerVial, 20)
        XCTAssertTrue(r.warnings.isEmpty)
    }

    func testVectorTenMilligramsInOneMillilitre() throws {
        let r = try ReconstitutionCalculator.calculate(
            vial: Amount(d("10"), .mg), diluentML: d("1"), dose: Amount(d("2.5"), .mg), syringe: .u100Mid)
        XCTAssertEqual(r.concentration, d("10"))
        XCTAssertEqual(r.drawML, d("0.25"))
        XCTAssertEqual(r.syringeUnits, d("25"))
        XCTAssertEqual(r.fullDosesPerVial, 4)
    }

    func testVectorWithAFractionalNumberOfDoses() throws {
        let r = try ReconstitutionCalculator.calculate(
            vial: Amount(d("2"), .mg), diluentML: d("2"), dose: Amount(d("0.3"), .mg), syringe: .u100Half)
        XCTAssertEqual(r.drawML, d("0.3"))
        XCTAssertEqual(r.syringeUnits, d("30"))
        XCTAssertEqual(r.fullDosesPerVial, 6)
        XCTAssertGreaterThan(r.dosesPerVial, d("6.66"))
        XCTAssertLessThan(r.dosesPerVial, d("6.67"))
        XCTAssertTrue(r.warnings.isEmpty, "30 units exactly fills a 0.3 mL syringe")
    }

    func testMassUnitsConvertBetweenMicrogramsAndMilligrams() throws {
        let r = try ReconstitutionCalculator.calculate(
            vial: Amount(d("5"), .mg), diluentML: d("2"), dose: Amount(d("250"), .mcg), syringe: .u100Full)
        XCTAssertEqual(r.drawML, d("0.1"))
        XCTAssertEqual(r.syringeUnits, d("10"))
        XCTAssertEqual(r.fullDosesPerVial, 20)
    }

    func testInternationalUnitsOnlyMatchInternationalUnits() throws {
        let r = try ReconstitutionCalculator.calculate(
            vial: Amount(d("10"), .iu), diluentML: d("1"), dose: Amount(d("2"), .iu), syringe: .u100Full)
        XCTAssertEqual(r.drawML, d("0.2"))
        XCTAssertEqual(r.syringeUnits, d("20"))

        XCTAssertThrowsError(try ReconstitutionCalculator.calculate(
            vial: Amount(d("10"), .iu), diluentML: d("1"), dose: Amount(d("2"), .mg), syringe: .u100Full)) {
            XCTAssertEqual($0 as? ReconstitutionError, .unitMismatch)
        }
    }

    func testU40SyringeScalesUnitsDifferently() throws {
        let r = try ReconstitutionCalculator.calculate(
            vial: Amount(d("5"), .mg), diluentML: d("2"), dose: Amount(d("0.25"), .mg), syringe: .u40Full)
        XCTAssertEqual(r.drawML, d("0.1"))
        XCTAssertEqual(r.syringeUnits, d("4"))
    }

    func testNonPositiveInputsThrow() {
        let ok = Amount(d("5"), .mg)
        let cases: [(Amount, Decimal, Amount)] = [
            (Amount(d("0"), .mg), d("2"), ok),
            (ok, d("0"), ok),
            (ok, d("2"), Amount(d("0"), .mg)),
            (Amount(d("-1"), .mg), d("2"), ok),
        ]
        for (vial, diluent, dose) in cases {
            XCTAssertThrowsError(try ReconstitutionCalculator.calculate(
                vial: vial, diluentML: diluent, dose: dose, syringe: .u100Full)) {
                XCTAssertEqual($0 as? ReconstitutionError, .nonPositiveInput)
            }
        }
    }

    func testWarningsForUnmeasurableOversizeAndImpossibleDraws() throws {
        let tiny = try ReconstitutionCalculator.calculate(
            vial: Amount(d("10"), .mg), diluentML: d("1"), dose: Amount(d("0.1"), .mg), syringe: .u100Full)
        XCTAssertEqual(tiny.warnings, [.drawBelowMeasurable(units: d("1"))])

        let big = try ReconstitutionCalculator.calculate(
            vial: Amount(d("5"), .mg), diluentML: d("2"), dose: Amount(d("1.5"), .mg), syringe: .u100Mid)
        XCTAssertEqual(big.warnings, [.drawExceedsSyringe(units: d("60"), capacity: d("50"))])

        let impossible = try ReconstitutionCalculator.calculate(
            vial: Amount(d("1"), .mg), diluentML: d("1"), dose: Amount(d("2"), .mg), syringe: .u100Full)
        XCTAssertTrue(impossible.warnings.contains(.doseExceedsVial))
    }

    func testStepByStepMathIsShown() throws {
        let r = try ReconstitutionCalculator.calculate(
            vial: Amount(d("5"), .mg), diluentML: d("2"), dose: Amount(d("0.25"), .mg), syringe: .u100Full)
        XCTAssertEqual(r.steps.map { $0.label }, ["Concentration", "Draw volume", "Syringe units", "Doses per vial"])
        XCTAssertEqual(r.steps[0].result, "2.5 mg/mL")
        XCTAssertEqual(r.steps[1].result, "0.1 mL")
        XCTAssertEqual(r.steps[2].result, "10 units")
    }

    func testReverseModeLandsOnWholeUnits() throws {
        let inMg = try ReconstitutionCalculator.diluentML(
            vial: Amount(d("5"), .mg), dose: Amount(d("0.25"), .mg), targetUnits: d("10"), syringe: .u100Full)
        XCTAssertEqual(inMg, d("2"))
        let inMcg = try ReconstitutionCalculator.diluentML(
            vial: Amount(d("5"), .mg), dose: Amount(d("250"), .mcg), targetUnits: d("10"), syringe: .u100Full)
        XCTAssertEqual(inMcg, d("2"))
        XCTAssertThrowsError(try ReconstitutionCalculator.diluentML(
            vial: Amount(d("5"), .iu), dose: Amount(d("1"), .mg), targetUnits: d("10"), syringe: .u100Full))
    }

    func testBlendOneToOne() throws {
        let r = try ReconstitutionCalculator.calculateBlend(
            totalVial: Amount(d("10"), .mg), ratios: [d("1"), d("1")], diluentML: d("2"),
            targetIndex: 0, targetDose: Amount(d("250"), .mcg), syringe: .u100Full)
        XCTAssertEqual(r.drawML, d("0.1"))
        XCTAssertEqual(r.syringeUnits, d("10"))
        XCTAssertEqual(r.componentDoses, [d("250"), d("250")])
    }

    func testBlendWithUnevenRatio() throws {
        // 9 mg total at 2:1 = 6 mg + 3 mg in 3 mL; asking for 500 mcg of the second component.
        let r = try ReconstitutionCalculator.calculateBlend(
            totalVial: Amount(d("9"), .mg), ratios: [d("2"), d("1")], diluentML: d("3"),
            targetIndex: 1, targetDose: Amount(d("500"), .mcg), syringe: .u100Full)
        XCTAssertEqual(r.drawML, d("0.5"))
        XCTAssertEqual(r.componentDoses, [d("1000"), d("500")])
    }

    func testInvalidBlendsThrow() {
        let vial = Amount(d("10"), .mg)
        let dose = Amount(d("250"), .mcg)
        XCTAssertThrowsError(try ReconstitutionCalculator.calculateBlend(
            totalVial: vial, ratios: [d("1")], diluentML: d("2"), targetIndex: 0, targetDose: dose, syringe: .u100Full)) {
            XCTAssertEqual($0 as? ReconstitutionError, .invalidBlend)
        }
        XCTAssertThrowsError(try ReconstitutionCalculator.calculateBlend(
            totalVial: vial, ratios: [d("1"), d("0")], diluentML: d("2"), targetIndex: 0, targetDose: dose, syringe: .u100Full))
        XCTAssertThrowsError(try ReconstitutionCalculator.calculateBlend(
            totalVial: vial, ratios: [d("1"), d("1")], diluentML: d("2"), targetIndex: 2, targetDose: dose, syringe: .u100Full))
    }

    // Property test over a grid: dose -> draw -> dose must round-trip for every syringe.
    func testDoseDrawDoseRoundTripAcrossAGrid() throws {
        let vials: [Decimal] = [1, 2, 5, 10, 15]
        let diluents = [d("0.5"), d("1"), d("2"), d("3")]
        let fractions = [d("0.05"), d("0.1"), d("0.2"), d("0.25"), d("0.5")]
        let syringes: [Syringe] = [.u100Half, .u100Mid, .u100Full, .u40Full]
        let tolerance = d("0.000000000000001")

        for vial in vials {
            for diluent in diluents {
                for fraction in fractions {
                    for syringe in syringes {
                        let dose = vial * fraction
                        let r = try ReconstitutionCalculator.calculate(
                            vial: Amount(vial, .mg), diluentML: diluent, dose: Amount(dose, .mg), syringe: syringe)
                        let backToDose = r.drawML * r.concentration
                        let diff = backToDose - dose
                        XCTAssertTrue(diff < tolerance && diff > -tolerance, "vial \(vial) diluent \(diluent) dose \(dose)")
                        XCTAssertEqual(r.syringeUnits, r.drawML * syringe.unitsPerML)
                    }
                }
            }
        }
    }
}
