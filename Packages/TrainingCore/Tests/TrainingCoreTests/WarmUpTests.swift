import XCTest
@testable import TrainingCore

final class WarmUpTests: XCTestCase {
    // Smallest plate 2.5 kg, so totals move in 5 kg steps.
    private let inventory: [Plate] = [2500, 2000, 1500, 1000, 500, 250].map { Plate(size: $0, pairs: 2) }

    func testStandardRampForAHundredKiloTopSet() {
        let steps = WarmUpGenerator.generate(topWeight: 10_000, bar: 2000, inventory: inventory)
        XCTAssertEqual(steps.map { $0.weight }, [4000, 6000, 7500, 9000])
        XCTAssertEqual(steps.map { $0.reps }, [8, 5, 3, 1])
    }

    func testStepsRoundToLoadableWeights() {
        let steps = WarmUpGenerator.generate(topWeight: 6000, bar: 2000, inventory: inventory)
        XCTAssertEqual(steps.map { $0.weight }, [2500, 3500, 4500, 5500])
        for step in steps {
            XCTAssertNotNil(PlateCalculator.load(target: step.weight, bar: 2000, inventory: inventory))
        }
    }

    func testTopWeightAtOrBelowTheBarGivesNoRamp() {
        XCTAssertTrue(WarmUpGenerator.generate(topWeight: 2000, bar: 2000, inventory: inventory).isEmpty)
        XCTAssertTrue(WarmUpGenerator.generate(topWeight: 1500, bar: 2000, inventory: inventory).isEmpty)
    }

    func testStepsThatCollapseOntoTheBarAreDropped() {
        XCTAssertTrue(WarmUpGenerator.generate(topWeight: 2500, bar: 2000, inventory: inventory).isEmpty)
    }

    func testRampIsStrictlyAscendingAndBelowTop() {
        for top in stride(from: 4000, through: 30_000, by: 500) {
            let steps = WarmUpGenerator.generate(topWeight: top, bar: 2000, inventory: inventory)
            XCTAssertEqual(steps.map { $0.weight }, steps.map { $0.weight }.sorted())
            XCTAssertEqual(Set(steps.map { $0.weight }).count, steps.count)
            for step in steps {
                XCTAssertGreaterThan(step.weight, 2000)
                XCTAssertLessThan(step.weight, top)
            }
        }
    }
}
