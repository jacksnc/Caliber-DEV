import XCTest
@testable import TrainingCore

final class PlateCalculatorTests: XCTestCase {
    // kg inventory in hundredths: 25, 20, 15, 10, 5, 2.5, 1.25 kg, two pairs each.
    private let kg: [Plate] = [2500, 2000, 1500, 1000, 500, 250, 125].map { Plate(size: $0, pairs: 2) }
    // lb inventory in hundredths: 45, 35, 25, 10, 5, 2.5 lb, two pairs each.
    private let lb: [Plate] = [4500, 3500, 2500, 1000, 500, 250].map { Plate(size: $0, pairs: 2) }

    func testHundredKilosOnTwentyKiloBar() throws {
        let load = try XCTUnwrap(PlateCalculator.load(target: 10_000, bar: 2000, inventory: kg))
        XCTAssertEqual(load.perSide, [2500, 1500])
        XCTAssertEqual(load.total, 10_000)
    }

    func testFewestPlatesThenHeaviestFirst() throws {
        let load = try XCTUnwrap(PlateCalculator.load(target: 14_250, bar: 2000, inventory: kg))
        XCTAssertEqual(load.perSide, [2500, 2500, 1000, 125])
    }

    func testPoundInventory() throws {
        let load = try XCTUnwrap(PlateCalculator.load(target: 22_500, bar: 4500, inventory: lb))
        XCTAssertEqual(load.perSide, [4500, 4500])
        XCTAssertEqual(load.total, 22_500)
    }

    func testEmptyBar() throws {
        let load = try XCTUnwrap(PlateCalculator.load(target: 2000, bar: 2000, inventory: kg))
        XCTAssertEqual(load.perSide, [])
    }

    func testOddHundredthsAreNotExactlyLoadable() {
        XCTAssertNil(PlateCalculator.load(target: 10_001, bar: 2000, inventory: kg))
    }

    func testBelowBarIsNotLoadable() {
        XCTAssertNil(PlateCalculator.load(target: 1500, bar: 2000, inventory: kg))
    }

    func testNeighborsAroundAnUnreachableTarget() throws {
        // 101 kg: per side 40.5 kg, smallest step is 1.25 kg per side.
        let n = PlateCalculator.neighbors(of: 10_100, bar: 2000, inventory: kg)
        XCTAssertEqual(try XCTUnwrap(n.below).total, 10_000)
        XCTAssertEqual(try XCTUnwrap(n.above).total, 10_250)
        let nearest = try XCTUnwrap(PlateCalculator.nearest(to: 10_100, bar: 2000, inventory: kg))
        XCTAssertEqual(nearest.total, 10_000)
    }

    func testNearestBelowBarReturnsTheBar() throws {
        let nearest = try XCTUnwrap(PlateCalculator.nearest(to: 1500, bar: 2000, inventory: kg))
        XCTAssertEqual(nearest.total, 2000)
    }

    func testLimitedInventoryCannotMakeHeavyLoads() throws {
        let single = [Plate(size: 2500, pairs: 1)]
        XCTAssertNil(PlateCalculator.load(target: 12_000, bar: 2000, inventory: single))
        let nearest = try XCTUnwrap(PlateCalculator.nearest(to: 12_000, bar: 2000, inventory: single))
        XCTAssertEqual(nearest.total, 7000)
    }

    func testEveryTwoAndAHalfKiloStepIsLoadable() throws {
        // Two pairs of 25/20/15/10/5/2.5/1.25 makes every 1.25 kg per-side step up to 157.5 kg.
        for target in stride(from: 2000, through: 33_500, by: 250) {
            let load = try XCTUnwrap(PlateCalculator.load(target: target, bar: 2000, inventory: kg), "target \(target)")
            XCTAssertEqual(load.total, target)
            XCTAssertEqual(load.perSide, load.perSide.sorted(by: >))
        }
    }
}
