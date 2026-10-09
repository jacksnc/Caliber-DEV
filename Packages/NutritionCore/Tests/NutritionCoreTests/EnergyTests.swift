import XCTest
@testable import NutritionCore

final class EnergyTests: XCTestCase {
    func testMifflinStJeor() {
        XCTAssertEqual(BMR.mifflinStJeor(weightKg: 80, heightCm: 180, ageYears: 30, sex: .male), 1780, accuracy: 1e-9)
        XCTAssertEqual(BMR.mifflinStJeor(weightKg: 60, heightCm: 165, ageYears: 25, sex: .female), 1345.25, accuracy: 1e-9)
    }

    func testKatchMcArdle() {
        XCTAssertEqual(BMR.katchMcArdle(leanBodyMassKg: 60), 1666, accuracy: 1e-9)
    }

    func testActivityMultipliersMatchTheBrief() {
        XCTAssertEqual(ActivityLevel.allCases.map { $0.rawValue }, [1.2, 1.375, 1.55, 1.725, 1.9])
    }

    func testMacroEnergy() {
        XCTAssertEqual(EnergyCheck.kcal(proteinG: 30, carbsG: 40, fatG: 10), 370, accuracy: 1e-9)
        XCTAssertEqual(EnergyCheck.kcal(proteinG: 30, carbsG: 40, fatG: 10, alcoholG: 10), 440, accuracy: 1e-9)
    }

    func testLabelConsistencyWithinTenPercent() throws {
        XCTAssertTrue(EnergyCheck.isConsistent(labelKcal: 370, proteinG: 30, carbsG: 40, fatG: 10))
        XCTAssertTrue(EnergyCheck.isConsistent(labelKcal: 400, proteinG: 30, carbsG: 40, fatG: 10))
        XCTAssertFalse(EnergyCheck.isConsistent(labelKcal: 450, proteinG: 30, carbsG: 40, fatG: 10))
        let mismatch = try XCTUnwrap(EnergyCheck.mismatchFraction(labelKcal: 400, proteinG: 30, carbsG: 40, fatG: 10))
        XCTAssertEqual(mismatch, 0.075, accuracy: 1e-9)
    }

    func testZeroLabelIsNotConsistent() {
        XCTAssertNil(EnergyCheck.mismatchFraction(labelKcal: 0, proteinG: 1, carbsG: 1, fatG: 1))
        XCTAssertFalse(EnergyCheck.isConsistent(labelKcal: 0, proteinG: 1, carbsG: 1, fatG: 1))
    }
}
