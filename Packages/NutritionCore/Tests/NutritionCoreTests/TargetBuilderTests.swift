import XCTest
@testable import NutritionCore

final class TargetBuilderTests: XCTestCase {
    private func male(rate: Double, bodyFat: Double? = nil, protein: Double? = nil) -> TargetInputs {
        TargetInputs(sex: .male, ageYears: 30, heightCm: 180, weightKg: 80, bodyFatFraction: bodyFat,
                     activity: .moderate, weeklyRateKg: rate, proteinPerKg: protein)
    }

    private func ready(_ outcome: TargetOutcome) throws -> (MacroTargets, Double, [TargetFlag]) {
        guard case let .ready(targets, tdee, flags) = outcome else {
            XCTFail("expected ready, got \(outcome)")
            throw NSError(domain: "test", code: 1)
        }
        return (targets, tdee, flags)
    }

    func testMaintenanceTargets() throws {
        let (targets, tdee, flags) = try ready(TargetBuilder.build(male(rate: 0)))
        XCTAssertEqual(tdee, 2759, accuracy: 0.01)
        XCTAssertEqual(targets.calories, 2759, accuracy: 0.01)
        XCTAssertEqual(targets.proteinG, 160, accuracy: 0.01)
        XCTAssertEqual(targets.fatG, 0.2 * 2759 / 9, accuracy: 0.01)
        XCTAssertEqual(targets.carbsG, 391.8, accuracy: 0.01)
        XCTAssertEqual(targets.fiberG, 14 * 2759 / 1000, accuracy: 0.01)
        XCTAssertTrue(flags.isEmpty)
    }

    func testModerateCutUsesHigherProtein() throws {
        let (targets, _, flags) = try ready(TargetBuilder.build(male(rate: -0.5)))
        XCTAssertEqual(targets.calories, 2209, accuracy: 0.01)
        XCTAssertEqual(targets.proteinG, 176, accuracy: 0.01)
        XCTAssertEqual(targets.carbsG, 265.8, accuracy: 0.01)
        XCTAssertTrue(flags.isEmpty)
    }

    func testLossRateIsCappedAtOnePercentOfBodyweight() throws {
        let (targets, _, flags) = try ready(TargetBuilder.build(male(rate: -1.2)))
        XCTAssertEqual(targets.calories, 2759 - 880, accuracy: 0.01)
        XCTAssertEqual(flags.count, 1)
        guard case let .rateCapped(rate) = flags[0] else { return XCTFail("expected rateCapped") }
        XCTAssertEqual(rate, -0.8, accuracy: 1e-9)
    }

    func testGainIsNotCapped() throws {
        let (targets, _, flags) = try ready(TargetBuilder.build(male(rate: 0.25)))
        XCTAssertEqual(targets.calories, 2759 + 275, accuracy: 0.01)
        XCTAssertTrue(flags.isEmpty)
    }

    func testKatchMcArdleIsUsedWhenBodyFatIsKnown() throws {
        let (_, tdee, _) = try ready(TargetBuilder.build(male(rate: 0, bodyFat: 0.20)))
        XCTAssertEqual(tdee, (370 + 21.6 * 64) * 1.55, accuracy: 0.01)
    }

    private func smallFemale(rate: Double, override: Bool = false, protein: Double? = nil) -> TargetInputs {
        TargetInputs(sex: .female, ageYears: 40, heightCm: 160, weightKg: 50, activity: .sedentary,
                     weeklyRateKg: rate, proteinPerKg: protein, clinicianOverrideFloor: override)
    }

    func testCalorieFloorIsAppliedAndFlagged() throws {
        let (targets, tdee, flags) = try ready(TargetBuilder.build(smallFemale(rate: -0.4)))
        XCTAssertEqual(tdee, 1366.8, accuracy: 0.01)
        XCTAssertEqual(targets.calories, 1200, accuracy: 1e-9)
        XCTAssertEqual(flags, [.calorieFloorApplied(floor: 1200)])
        XCTAssertEqual(targets.proteinG, 110, accuracy: 0.01)
        XCTAssertEqual(targets.fatG, 30, accuracy: 0.01)
        XCTAssertEqual(targets.carbsG, 122.5, accuracy: 0.01)
    }

    func testClinicianOverrideKeepsTheLowTargetButSaysSo() throws {
        let (targets, _, flags) = try ready(TargetBuilder.build(smallFemale(rate: -0.4, override: true)))
        XCTAssertEqual(targets.calories, 1366.8 - 440, accuracy: 0.01)
        XCTAssertEqual(flags, [.calorieFloorOverridden(floor: 1200)])
    }

    func testCarbsNeverGoNegative() throws {
        let (targets, _, flags) = try ready(TargetBuilder.build(smallFemale(rate: -0.4, protein: 5)))
        XCTAssertEqual(targets.carbsG, 0)
        XCTAssertTrue(flags.contains(.macrosExceedCalories))
    }

    func testUnderEighteenIsBlocked() {
        var input = male(rate: 0)
        input.ageYears = 17
        XCTAssertEqual(TargetBuilder.build(input), .blocked(.underEighteen))
    }

    func testInvalidInputIsBlocked() {
        var input = male(rate: 0)
        input.weightKg = 0
        XCTAssertEqual(TargetBuilder.build(input), .blocked(.invalidInput))
    }

    func testUnderweightBlocksEveryDeficitButNotMaintenanceOrGain() {
        // 50 kg at 169 cm is a BMI of about 17.5.
        func person(_ rate: Double) -> TargetInputs {
            TargetInputs(sex: .female, ageYears: 30, heightCm: 169, weightKg: 50, activity: .light, weeklyRateKg: rate)
        }
        XCTAssertLessThan(TargetBuilder.bmi(weightKg: 50, heightCm: 169), 18.5)
        XCTAssertEqual(TargetBuilder.build(person(-0.1)), .blocked(.underweightDeficit))
        XCTAssertEqual(TargetBuilder.build(person(-0.5)), .blocked(.underweightDeficit))
        if case .blocked = TargetBuilder.build(person(0)) { XCTFail("maintenance must be allowed") }
        if case .blocked = TargetBuilder.build(person(0.2)) { XCTFail("gain must be allowed") }
    }

    func testManualNineHundredCalorieTargetIsRefused() {
        let female = TargetBuilder.guardCalories(900, sex: .female)
        XCTAssertFalse(female.allowed)
        XCTAssertEqual(female.adjustedCalories, 1200)
        let male = TargetBuilder.guardCalories(900, sex: .male)
        XCTAssertFalse(male.allowed)
        XCTAssertEqual(male.adjustedCalories, 1500)
        XCTAssertTrue(TargetBuilder.guardCalories(1300, sex: .female).allowed)
        let overridden = TargetBuilder.guardCalories(900, sex: .female, clinicianOverride: true)
        XCTAssertTrue(overridden.allowed)
        XCTAssertEqual(overridden.adjustedCalories, 900)
    }
}
