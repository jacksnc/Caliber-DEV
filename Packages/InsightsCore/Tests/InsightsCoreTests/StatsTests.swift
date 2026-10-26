import XCTest
@testable import InsightsCore

final class StatsTests: XCTestCase {
    func testMedianAndMad() {
        XCTAssertEqual(Stats.median([3, 1, 2]), 2)
        XCTAssertEqual(Stats.median([1, 2, 3, 4]), 2.5)
        XCTAssertNil(Stats.median([]))
        // Median 3; deviations [2, 1, 0, 1, 97]; their median is 1.
        XCTAssertEqual(Stats.mad([1, 2, 3, 4, 100]), 1)
        XCTAssertNil(Stats.mad([]))
    }

    func testTheilSenRecoversAnExactLine() throws {
        let x = (0..<10).map(Double.init)
        let line = try XCTUnwrap(Stats.theilSen(x: x, y: x.map { 2 * $0 + 1 }))
        XCTAssertEqual(line.slope, 2, accuracy: 1e-12)
        XCTAssertEqual(line.intercept, 1, accuracy: 1e-12)
    }

    func testTheilSenIgnoresAnOutlier() throws {
        var x = (0..<10).map(Double.init)
        var y = x.map { 2 * $0 + 1 }
        x.append(10)
        y.append(1000)
        let line = try XCTUnwrap(Stats.theilSen(x: x, y: y))
        XCTAssertEqual(line.slope, 2, accuracy: 1e-12)
        XCTAssertEqual(line.intercept, 1, accuracy: 1e-12)
    }

    func testTheilSenDegenerateInput() {
        XCTAssertNil(Stats.theilSen(x: [1], y: [1]))
        XCTAssertNil(Stats.theilSen(x: [1, 2], y: [1]))
        XCTAssertNil(Stats.theilSen(x: [3, 3, 3], y: [1, 2, 3]), "no horizontal spread means no slope")
    }

    func testTheilSenSubsamplesLongSeries() throws {
        let x = (0..<4000).map(Double.init)
        let line = try XCTUnwrap(Stats.theilSen(x: x, y: x.map { 0.5 * $0 + 3 }, maxPoints: 300))
        XCTAssertEqual(line.slope, 0.5, accuracy: 1e-9)
    }

    func testRanksShareTiedPositions() {
        XCTAssertEqual(Stats.ranks([10, 20, 20, 30]), [1, 2.5, 2.5, 4])
        XCTAssertEqual(Stats.ranks([30, 10, 20]), [3, 1, 2])
        XCTAssertEqual(Stats.ranks([]), [])
    }

    func testPearson() throws {
        XCTAssertEqual(try XCTUnwrap(Stats.pearson([1, 2, 3], [2, 4, 6])), 1, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(Stats.pearson([1, 2, 3], [6, 4, 2])), -1, accuracy: 1e-12)
        XCTAssertNil(Stats.pearson([1, 2, 3], [5, 5, 5]))
        XCTAssertNil(Stats.pearson([1], [1]))
    }

    func testSpearmanSeesMonotonicRelationshipsThatArentLinear() throws {
        let x = (1...20).map(Double.init)
        XCTAssertEqual(try XCTUnwrap(Stats.spearman(x, x.map { $0 * $0 * $0 })), 1, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(Stats.spearman(x, x.reversed())), -1, accuracy: 1e-12)
        XCTAssertNil(Stats.spearman([1, 2, 3], [1, 2]))
    }

    func testSplitMixMatchesTheReferenceImplementation() {
        var rng = Stats.SplitMix64(seed: 0)
        XCTAssertEqual(rng.next(), 0xE220_A839_7B1D_CDAF)
    }

    func testBootstrapIsDeterministicAndBounded() throws {
        let x = (1...30).map(Double.init)
        let y = x.enumerated().map { index, value in value + Double((index * 7) % 5) - 2 }
        let first = try XCTUnwrap(Stats.bootstrapInterval(x: x, y: y, seed: 42) { Stats.spearman($0, $1) })
        let again = try XCTUnwrap(Stats.bootstrapInterval(x: x, y: y, seed: 42) { Stats.spearman($0, $1) })
        XCTAssertEqual(first, again)
        XCTAssertGreaterThan(first.lowerBound, 0.5)
        XCTAssertLessThanOrEqual(first.upperBound, 1)
        XCTAssertLessThanOrEqual(first.lowerBound, first.upperBound)
    }

    func testBootstrapRejectsTooFewIterations() {
        XCTAssertNil(Stats.bootstrapInterval(x: [1, 2, 3], y: [1, 2, 3], iterations: 10) { Stats.spearman($0, $1) })
    }
}
