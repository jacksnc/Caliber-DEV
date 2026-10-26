import XCTest
@testable import TrainingCore

final class OneRepMaxTests: XCTestCase {
    // Golden vectors from brief §9.3: 100 kg x 5.
    func testEpleyGoldenVector() throws {
        let value = try XCTUnwrap(OneRepMax.estimate(weight: 100, reps: 5, formula: .epley))
        XCTAssertEqual(value, 116.67, accuracy: 0.01)
    }

    func testBrzyckiGoldenVector() throws {
        let value = try XCTUnwrap(OneRepMax.estimate(weight: 100, reps: 5, formula: .brzycki))
        XCTAssertEqual(value, 112.5, accuracy: 0.01)
    }

    func testOConnerGoldenVector() throws {
        let value = try XCTUnwrap(OneRepMax.estimate(weight: 100, reps: 5, formula: .oConner))
        XCTAssertEqual(value, 112.5, accuracy: 0.01)
    }

    func testLombardiGoldenVector() throws {
        let value = try XCTUnwrap(OneRepMax.estimate(weight: 100, reps: 5, formula: .lombardi))
        XCTAssertEqual(value, 117.46, accuracy: 0.01)
    }

    func testPublishedFormsWithinTolerance() throws {
        let mayhew = try XCTUnwrap(OneRepMax.estimate(weight: 100, reps: 5, formula: .mayhew))
        let wathan = try XCTUnwrap(OneRepMax.estimate(weight: 100, reps: 5, formula: .wathan))
        let lander = try XCTUnwrap(OneRepMax.estimate(weight: 100, reps: 5, formula: .lander))
        XCTAssertEqual(mayhew, 119.01, accuracy: 0.1)
        XCTAssertEqual(wathan, 116.58, accuracy: 0.1)
        XCTAssertEqual(lander, 113.71, accuracy: 0.1)
    }

    func testSingleRepReturnsTheWeight() {
        for formula in OneRepMaxFormula.allCases {
            XCTAssertEqual(OneRepMax.estimate(weight: 140, reps: 1, formula: formula), 140)
        }
    }

    func testInvalidInputReturnsNil() {
        XCTAssertNil(OneRepMax.estimate(weight: 0, reps: 5))
        XCTAssertNil(OneRepMax.estimate(weight: -10, reps: 5))
        XCTAssertNil(OneRepMax.estimate(weight: 100, reps: 0))
        XCTAssertNil(OneRepMax.estimate(weight: 100, reps: 31))
    }

    func testEveryFormulaGrowsWithRepsAndExceedsTheWeight() {
        for formula in OneRepMaxFormula.allCases {
            var previous = 100.0
            for reps in 2...20 {
                guard let value = OneRepMax.estimate(weight: 100, reps: reps, formula: formula) else {
                    return XCTFail("\(formula) returned nil at \(reps) reps")
                }
                XCTAssertGreaterThan(value, previous, "\(formula) at \(reps) reps")
                previous = value
            }
        }
    }

    func testRPEAdjustmentUsesRepsInReserve() throws {
        // 5 reps @ RPE 8 -> 2 RIR -> 7 effective reps.
        let estimate = try XCTUnwrap(OneRepMax.estimate(weight: 100, reps: 5, rpe: 8, formula: .epley))
        XCTAssertEqual(estimate.effectiveReps, 7, accuracy: 1e-9)
        XCTAssertEqual(estimate.value, 123.33, accuracy: 0.01)
    }

    func testRPETenIsPlainEstimate() throws {
        let adjusted = try XCTUnwrap(OneRepMax.estimate(weight: 100, reps: 5, rpe: 10, formula: .epley))
        let plain = try XCTUnwrap(OneRepMax.estimate(weight: 100, reps: 5, formula: .epley))
        XCTAssertEqual(adjusted.value, plain, accuracy: 1e-9)
    }

    func testConfidenceTiers() {
        XCTAssertEqual(OneRepMax.confidence(forEffectiveReps: 5), .high)
        XCTAssertEqual(OneRepMax.confidence(forEffectiveReps: 10), .high)
        XCTAssertEqual(OneRepMax.confidence(forEffectiveReps: 11), .medium)
        XCTAssertEqual(OneRepMax.confidence(forEffectiveReps: 12), .medium)
        XCTAssertEqual(OneRepMax.confidence(forEffectiveReps: 13), .low)
        XCTAssertTrue(EstimateConfidence.low < EstimateConfidence.high)
    }

    func testFractionAndWeightForRepsRoundTrip() throws {
        let fraction = try XCTUnwrap(OneRepMax.fractionOfOneRepMax(reps: 5, formula: .epley))
        XCTAssertEqual(fraction, 1 / (1 + 5.0 / 30), accuracy: 1e-9)
        let weight = try XCTUnwrap(OneRepMax.weight(forReps: 5, oneRepMax: 140, formula: .epley))
        let back = try XCTUnwrap(OneRepMax.estimate(weight: weight, reps: 5, formula: .epley))
        XCTAssertEqual(back, 140, accuracy: 1e-9)
    }
}
