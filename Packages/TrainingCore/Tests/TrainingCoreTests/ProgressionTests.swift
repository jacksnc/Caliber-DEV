import XCTest
@testable import TrainingCore

final class ProgressionTests: XCTestCase {
    // MARK: linear

    func testLinearAddsLoadAfterASuccessfulSession() {
        let scheme = LinearProgression(increment: 2.5, rounding: .increment(2.5))
        let step = scheme.next(from: .init(weight: 100, consecutiveFailures: 2), completedAllReps: true)
        XCTAssertEqual(step.state.weight, 102.5, accuracy: 1e-9)
        XCTAssertEqual(step.state.consecutiveFailures, 0)
        XCTAssertEqual(step.reason, "Completed all reps: add 2.5 to 102.5")
    }

    func testLinearRepeatsAfterOneOrTwoMissesThenDeloads() {
        let scheme = LinearProgression(increment: 2.5, failuresBeforeDeload: 3, deloadFactor: 0.9, rounding: .increment(2.5))
        var state = LinearProgression.State(weight: 102.5)

        state = scheme.next(from: state, completedAllReps: false).state
        XCTAssertEqual(state.weight, 102.5, accuracy: 1e-9)
        XCTAssertEqual(state.consecutiveFailures, 1)

        let second = scheme.next(from: state, completedAllReps: false)
        XCTAssertEqual(second.state.consecutiveFailures, 2)
        XCTAssertEqual(second.reason, "Missed reps (2 of 3 before a deload): repeat 102.5")

        let third = scheme.next(from: second.state, completedAllReps: false)
        // 102.5 x 0.9 = 92.25 -> nearest 2.5 is 92.5
        XCTAssertEqual(third.state.weight, 92.5, accuracy: 1e-9)
        XCTAssertEqual(third.state.consecutiveFailures, 0)
        XCTAssertEqual(third.reason, "3 missed sessions in a row: deload to 92.5")
    }

    func testASuccessResetsTheFailureCount() {
        let scheme = LinearProgression()
        let step = scheme.next(from: .init(weight: 60, consecutiveFailures: 2), completedAllReps: true)
        XCTAssertEqual(step.state.consecutiveFailures, 0)
    }

    // MARK: double progression

    func testDoubleProgressionAddsLoadWhenEverySetHitsTheTop() {
        let scheme = DoubleProgression(repRange: 8...12, increment: 2.5)
        let next = scheme.next(weight: 80, repsPerSet: [12, 12, 12])
        XCTAssertEqual(next.weight, 82.5, accuracy: 1e-9)
        XCTAssertEqual(next.targetReps, 8)
    }

    func testDoubleProgressionAimsForOneMoreRepOnTheWeakestSet() {
        let scheme = DoubleProgression(repRange: 8...12, increment: 2.5)
        let next = scheme.next(weight: 80, repsPerSet: [12, 11, 10])
        XCTAssertEqual(next.weight, 80, accuracy: 1e-9)
        XCTAssertEqual(next.targetReps, 11)
        XCTAssertEqual(next.reason, "Lowest set was 10: aim for 11 reps on every set at 80")
    }

    func testDoubleProgressionHoldsWhenBelowTheRange() {
        let scheme = DoubleProgression(repRange: 8...12)
        let next = scheme.next(weight: 80, repsPerSet: [7, 8, 8])
        XCTAssertEqual(next.weight, 80, accuracy: 1e-9)
        XCTAssertEqual(next.targetReps, 8)
    }

    func testDoubleProgressionWithNoSets() {
        let next = DoubleProgression(repRange: 8...12).next(weight: 80, repsPerSet: [])
        XCTAssertEqual(next.targetReps, 8)
        XCTAssertEqual(next.weight, 80)
    }

    // MARK: waves

    func testWavePrescription() {
        let week1 = WaveEngine.prescription(trainingMax: 100, week: 0, rounding: .increment(2.5))
        XCTAssertEqual(week1.map { $0.weight }, [70, 80, 90])
        XCTAssertEqual(week1.map { $0.reps }, [5, 5, 5])
        XCTAssertEqual(week1.map { $0.isAMRAP }, [false, false, true])

        let week2 = WaveEngine.prescription(trainingMax: 100, week: 1, rounding: .increment(2.5))
        XCTAssertEqual(week2.map { $0.weight }, [75, 85, 95])
        XCTAssertEqual(week2.map { $0.reps }, [3, 3, 3])
    }

    func testWaveWrapsAroundAndRoundsToTheBar() {
        let wrapped = WaveEngine.prescription(trainingMax: 100, week: 4, rounding: .increment(2.5))
        XCTAssertEqual(wrapped.map { $0.weight }, [70, 80, 90])
        let rounded = WaveEngine.prescription(trainingMax: 103, week: 0, rounding: .increment(2.5))
        XCTAssertEqual(rounded.map { $0.weight }, [72.5, 82.5, 92.5])   // 72.1, 82.4, 92.7
    }

    func testWaveEdgeCases() {
        XCTAssertTrue(WaveEngine.prescription(trainingMax: 0, week: 0).isEmpty)
        XCTAssertTrue(WaveEngine.prescription(trainingMax: 100, week: 0, template: WaveTemplate(weeks: [], cycleIncrement: 5)).isEmpty)
        XCTAssertEqual(WaveEngine.nextTrainingMax(100), 105, accuracy: 1e-9)
    }

    // MARK: RPE autoregulation

    func testRPEPrescriptionFromAKnownOneRepMax() throws {
        // 5 reps at RPE 8 is 7 effective reps: Epley factor 1 + 7/30, so 140 / 1.2333 = 113.51 -> 112.5.
        let set = try XCTUnwrap(RPEAutoregulation.prescribe(
            oneRepMax: 140, targetReps: 5, targetRPE: 8, rounding: .increment(2.5)))
        XCTAssertEqual(set.weight, 112.5, accuracy: 1e-9)
        XCTAssertEqual(set.reps, 5)
    }

    func testRPETenMeansNoReserve() throws {
        let set = try XCTUnwrap(RPEAutoregulation.prescribe(oneRepMax: 140, targetReps: 5, targetRPE: 10))
        XCTAssertEqual(set.weight, 140 / (1 + 5.0 / 30), accuracy: 1e-9)
    }

    func testLastSetAtTheSameEffortRepeatsTheLoad() throws {
        let result = try XCTUnwrap(RPEAutoregulation.fromLastSet(
            weight: 100, reps: 5, rpe: 8, targetReps: 5, targetRPE: 8, rounding: .increment(2.5)))
        XCTAssertEqual(result.estimatedOneRepMax, 100 * (1 + 7.0 / 30), accuracy: 1e-9)
        XCTAssertEqual(result.next.weight, 100, accuracy: 1e-9)
    }

    func testAHarderLastSetLowersTheNextLoad() throws {
        // 100 x 5 @ RPE 9 -> 6 effective reps -> e1RM 120 -> 5 @ RPE 8 is 120 / 1.2333 = 97.3 -> 97.5.
        let result = try XCTUnwrap(RPEAutoregulation.fromLastSet(
            weight: 100, reps: 5, rpe: 9, targetReps: 5, targetRPE: 8, rounding: .increment(2.5)))
        XCTAssertEqual(result.estimatedOneRepMax, 120, accuracy: 1e-9)
        XCTAssertEqual(result.next.weight, 97.5, accuracy: 1e-9)
    }

    func testRPEInvalidInput() {
        XCTAssertNil(RPEAutoregulation.prescribe(oneRepMax: 0, targetReps: 5, targetRPE: 8))
        XCTAssertNil(RPEAutoregulation.prescribe(oneRepMax: 140, targetReps: 0, targetRPE: 8))
    }

    // MARK: back-off

    func testBackoffSets() {
        let sets = BackoffEngine.sets(topWeight: 102.5, percent: 0.10, count: 3, reps: 8, rounding: .increment(2.5))
        XCTAssertEqual(sets.count, 3)
        for set in sets {
            XCTAssertEqual(set.weight, 92.5, accuracy: 1e-9)   // 92.25 -> 92.5
            XCTAssertEqual(set.reps, 8)
        }
        XCTAssertTrue(BackoffEngine.sets(topWeight: 100, percent: 1.2, count: 3, reps: 8).isEmpty)
    }
}
