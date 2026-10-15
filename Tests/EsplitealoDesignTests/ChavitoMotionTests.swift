import XCTest
@testable import EsplitealoDesign

final class ChavitoMotionTests: XCTestCase {
    private let sampleTimes: [TimeInterval] = stride(from: 0, through: 30, by: 0.05).map { $0 }

    // MARK: Reduce Motion

    func testReduceMotionDisablesEveryLoop() {
        for expression in ChavitoExpression.allCases {
            let motion = ChavitoMotion(expression: expression, reduceMotion: true)
            XCTAssertFalse(motion.isAnimated, "\(expression)")
            XCTAssertTrue(motion.activeLoops.isEmpty, "\(expression)")
        }
    }

    func testReduceMotionAlwaysYieldsRestPose() {
        for expression in ChavitoExpression.allCases {
            let motion = ChavitoMotion(expression: expression, reduceMotion: true)
            for t in sampleTimes {
                XCTAssertEqual(motion.pose(at: t), .rest)
                XCTAssertEqual(motion.pose(at: t, reactionElapsed: 0.1), .rest)
            }
        }
    }

    // MARK: Loop selection

    func testActiveLoopsPerExpression() {
        func loops(_ e: ChavitoExpression) -> Set<ChavitoLoop> {
            ChavitoMotion(expression: e, reduceMotion: false).activeLoops
        }
        XCTAssertEqual(loops(.neutral), [.blink, .bob])
        XCTAssertEqual(loops(.worried), [.blink, .bob])
        XCTAssertEqual(loops(.happy), [.bob])
        XCTAssertEqual(loops(.thinking), [.blink, .bob, .thinkingTilt])
    }

    func testMotionIsAnimatedWhenAllowed() {
        for expression in ChavitoExpression.allCases {
            XCTAssertTrue(ChavitoMotion(expression: expression, reduceMotion: false).isAnimated)
        }
    }

    // MARK: Blink

    func testEyesStartOpen() {
        let motion = ChavitoMotion(expression: .neutral, reduceMotion: false)
        XCTAssertEqual(motion.pose(at: 0).eyeOpenness, 1)
    }

    func testBlinkClosesEyesMidBlinkThenReopens() {
        let motion = ChavitoMotion(expression: .neutral, reduceMotion: false)
        let mid = ChavitoMotion.blinkOffset + ChavitoMotion.blinkDuration / 2
        XCTAssertLessThan(motion.pose(at: mid).eyeOpenness, 0.15)
        XCTAssertGreaterThanOrEqual(motion.pose(at: mid).eyeOpenness, 0)
        let after = ChavitoMotion.blinkOffset + ChavitoMotion.blinkDuration + 0.01
        XCTAssertEqual(motion.pose(at: after).eyeOpenness, 1)
    }

    func testBlinkRepeatsEveryPeriod() {
        let motion = ChavitoMotion(expression: .worried, reduceMotion: false)
        let mid = ChavitoMotion.blinkOffset + ChavitoMotion.blinkDuration / 2
        XCTAssertEqual(
            motion.pose(at: mid).eyeOpenness,
            motion.pose(at: mid + 3 * ChavitoMotion.blinkPeriod).eyeOpenness,
            accuracy: 1e-9
        )
    }

    func testHappyNeverBlinksBecauseEyesAreAlreadyShut() {
        let motion = ChavitoMotion(expression: .happy, reduceMotion: false)
        for t in sampleTimes { XCTAssertEqual(motion.pose(at: t).eyeOpenness, 1) }
    }

    func testEyeOpennessStaysInUnitRange() {
        let motion = ChavitoMotion(expression: .thinking, reduceMotion: false)
        for t in sampleTimes {
            let o = motion.pose(at: t).eyeOpenness
            XCTAssertTrue((0...1).contains(o), "t=\(t) openness=\(o)")
        }
    }

    // MARK: Bob

    func testBobStartsAtRestAndStaysWithinAmplitude() {
        let motion = ChavitoMotion(expression: .neutral, reduceMotion: false)
        XCTAssertEqual(motion.pose(at: 0).bobOffset, 0, accuracy: 1e-9)
        for t in sampleTimes {
            XCTAssertLessThanOrEqual(abs(motion.pose(at: t).bobOffset), ChavitoMotion.bobAmplitude + 1e-9)
        }
    }

    func testBobPeaksAtQuarterPeriodAndRepeats() {
        let motion = ChavitoMotion(expression: .happy, reduceMotion: false)
        XCTAssertEqual(motion.pose(at: ChavitoMotion.bobPeriod / 4).bobOffset, ChavitoMotion.bobAmplitude, accuracy: 1e-9)
        XCTAssertEqual(
            motion.pose(at: 1.3).bobOffset,
            motion.pose(at: 1.3 + ChavitoMotion.bobPeriod).bobOffset,
            accuracy: 1e-9
        )
    }

    // MARK: Thinking tilt

    func testOnlyThinkingTilts() {
        for expression in ChavitoExpression.allCases where expression != .thinking {
            let motion = ChavitoMotion(expression: expression, reduceMotion: false)
            for t in sampleTimes { XCTAssertEqual(motion.pose(at: t).tiltDegrees, 0) }
        }
    }

    func testThinkingTiltSwaysWithinLimit() {
        let motion = ChavitoMotion(expression: .thinking, reduceMotion: false)
        XCTAssertEqual(motion.pose(at: 0).tiltDegrees, 0, accuracy: 1e-9)
        XCTAssertEqual(
            motion.pose(at: ChavitoMotion.tiltPeriod / 4).tiltDegrees,
            ChavitoMotion.tiltMaxDegrees,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            motion.pose(at: 3 * ChavitoMotion.tiltPeriod / 4).tiltDegrees,
            -ChavitoMotion.tiltMaxDegrees,
            accuracy: 1e-9
        )
        for t in sampleTimes {
            XCTAssertLessThanOrEqual(abs(motion.pose(at: t).tiltDegrees), ChavitoMotion.tiltMaxDegrees + 1e-9)
        }
    }

    // MARK: Reaction

    func testReactionPopsThenSettles() {
        let motion = ChavitoMotion(expression: .happy, reduceMotion: false)
        XCTAssertEqual(motion.pose(at: 0, reactionElapsed: 0).scale, 1, accuracy: 1e-9)
        let peak = motion.pose(at: 0, reactionElapsed: ChavitoMotion.reactionDuration / 2).scale
        XCTAssertEqual(peak, 1 + ChavitoMotion.reactionPeakScale, accuracy: 1e-9)
        XCTAssertEqual(motion.pose(at: 0, reactionElapsed: ChavitoMotion.reactionDuration).scale, 1, accuracy: 1e-9)
        XCTAssertEqual(motion.pose(at: 0, reactionElapsed: ChavitoMotion.reactionDuration + 5).scale, 1)
        XCTAssertEqual(motion.pose(at: 0).scale, 1)
    }

    func testIsReactingWindow() {
        XCTAssertTrue(ChavitoMotion.isReacting(elapsed: 0.1))
        XCTAssertFalse(ChavitoMotion.isReacting(elapsed: ChavitoMotion.reactionDuration))
        XCTAssertFalse(ChavitoMotion.isReacting(elapsed: -1))
    }

    func testRestPoseValues() {
        XCTAssertEqual(ChavitoPose.rest, ChavitoPose(eyeOpenness: 1, bobOffset: 0, tiltDegrees: 0, scale: 1))
    }
}
