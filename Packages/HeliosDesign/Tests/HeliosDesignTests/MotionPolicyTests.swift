import XCTest
@testable import HeliosDesign

final class MotionPolicyTests: XCTestCase {
    func testSpeedsAreTheTokens() {
        XCTAssertEqual(HeliosMotionSpeed.fast.duration, HeliosTokens.motion.fast)
        XCTAssertEqual(HeliosMotionSpeed.base.duration, HeliosTokens.motion.base)
        XCTAssertEqual(HeliosMotionSpeed.slow.duration, HeliosTokens.motion.slow)
    }

    func testReduceMotionLeavesOnlyACrossfade() {
        let reduced = HeliosMotionPolicy(reduceMotion: true)
        XCTAssertEqual(reduced.entranceOffset, 0)
        XCTAssertEqual(reduced.entranceScale, 1)
        XCTAssertEqual(reduced.pressedScale, 1)
        XCTAssertLessThan(reduced.pressedOpacity, 1, "a press still needs a visible cue")
        XCTAssertFalse(reduced.allowsFlourish)
        for order in 0...10 {
            XCTAssertEqual(reduced.entranceDelay(order: order), 0)
        }
        XCTAssertEqual(reduced.drawInDuration, HeliosTokens.motion.fast)
    }

    func testFullMotionStaysSubtle() {
        let full = HeliosMotionPolicy(reduceMotion: false)
        XCTAssertTrue(full.allowsFlourish)
        XCTAssertGreaterThan(full.entranceOffset, 0)
        XCTAssertLessThanOrEqual(full.entranceOffset, 16)
        XCTAssertGreaterThanOrEqual(full.entranceScale, 0.95)
        XCTAssertGreaterThanOrEqual(full.pressedScale, 0.95)
        XCTAssertLessThanOrEqual(full.drawInDuration, HeliosMotionPolicy.drawInLimit, "the brief caps chart draw-in at 400 ms")
    }

    func testStaggerIsCappedSoLongScreensDoNotWait() {
        let full = HeliosMotionPolicy(reduceMotion: false)
        XCTAssertEqual(full.entranceDelay(order: -3), 0)
        XCTAssertEqual(full.entranceDelay(order: 0), 0)
        XCTAssertLessThan(full.entranceDelay(order: 1), full.entranceDelay(order: 2))
        let cap = full.entranceDelay(order: HeliosMotionPolicy.maxStaggerSteps)
        XCTAssertEqual(full.entranceDelay(order: 50), cap)
        XCTAssertLessThanOrEqual(cap, HeliosTokens.motion.fast * 1.5)
    }

    func testToastsStayLongerForVoiceOver() {
        XCTAssertGreaterThan(
            HeliosMotionPolicy.toastDuration(voiceOver: true),
            HeliosMotionPolicy.toastDuration(voiceOver: false)
        )
        XCTAssertGreaterThanOrEqual(HeliosMotionPolicy.toastDuration(voiceOver: false), 2)
    }
}
