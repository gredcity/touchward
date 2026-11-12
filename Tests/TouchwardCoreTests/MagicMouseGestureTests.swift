import CoreGraphics
import XCTest
@testable import TouchwardCore

final class MagicMouseGestureTests: XCTestCase {
    private func frame(_ points: [(UInt8, CGFloat, CGFloat)], at time: TimeInterval) -> MappedFrame {
        MappedFrame(contacts: points.map {
            MappedContact(id: $0.0, point: CGPoint(x: $0.1, y: $0.2))
        }, time: time)
    }

    private func empty(at time: TimeInterval) -> MappedFrame {
        frame([], at: time)
    }

    private func two(at time: TimeInterval, x: CGFloat = 100,
                     ids: [UInt8] = [1, 2]) -> MappedFrame {
        frame([(ids[0], x, 100), (ids[1], x + 100, 100)], at: time)
    }

    private func tap(_ r: inout GestureRecognizer, at time: TimeInterval,
                     x: CGFloat = 100) -> [GestureEvent] {
        var events = r.handle(two(at: time, x: x))
        events += r.handle(empty(at: time + 0.1))
        return events
    }

    func testOneFingerMotionDragsBothAxesAndReleasesOnLift() {
        var r = GestureRecognizer()
        _ = r.handle(frame([(1, 100, 100)], at: 0))

        XCTAssertEqual(r.handle(frame([(1, 130, 120)], at: 0.05)), [
            .dragBegan(at: CGPoint(x: 100, y: 100)), .dragMoved(to: CGPoint(x: 130, y: 120)),
        ])
        XCTAssertEqual(r.handle(frame([(1, 120, 150)], at: 0.1)), [
            .dragMoved(to: CGPoint(x: 120, y: 150)),
        ])
        XCTAssertEqual(r.tick(at: 1), [])
        XCTAssertEqual(r.handle(empty(at: 1.1)), [
            .dragEnded(at: CGPoint(x: 120, y: 150)), .sessionEnded,
        ])
    }

    func testHoldWaitsForLiftBeforeRightClicking() {
        var r = GestureRecognizer()
        _ = r.handle(frame([(1, 100, 100)], at: 0))

        XCTAssertEqual(r.tick(at: 0.65), [])
        XCTAssertEqual(r.tick(at: 0.9), [])
        XCTAssertEqual(r.handle(empty(at: 1)), [
            .rightClick(at: CGPoint(x: 100, y: 100)), .sessionEnded,
        ])
        XCTAssertEqual(r.handle(empty(at: 1.1)), [])
    }

    func testHoldThenMoveDragsAndBalancesTheMouseButton() {
        var r = GestureRecognizer()
        _ = r.handle(frame([(1, 100, 100)], at: 0))
        XCTAssertEqual(r.tick(at: 0.6), [])

        XCTAssertEqual(r.handle(frame([(1, 180, 100)], at: 0.65)), [
            .dragBegan(at: CGPoint(x: 100, y: 100)),
            .dragMoved(to: CGPoint(x: 180, y: 100)),
        ])
        XCTAssertEqual(r.handle(frame([(1, 200, 120)], at: 0.7)), [
            .dragMoved(to: CGPoint(x: 200, y: 120)),
        ])
        XCTAssertEqual(r.handle(empty(at: 0.75)), [
            .dragEnded(at: CGPoint(x: 200, y: 120)), .sessionEnded,
        ])
    }

    /// Right-click waits out the double-tap window so a Mission Control double-tap never
    /// leaves a stray context menu behind.
    func testTwoFingerTapRightClicksOnceTheDoubleTapWindowPasses() {
        var r = GestureRecognizer()
        XCTAssertEqual(tap(&r, at: 0), [.sessionEnded])
        XCTAssertTrue(r.needsClock, "the heartbeat must keep ticking to deliver it")

        XCTAssertEqual(r.tick(at: 0.3), [], "still inside the double-tap window")
        XCTAssertEqual(r.tick(at: 0.5), [.rightClick(at: CGPoint(x: 150, y: 100))])
        XCTAssertEqual(r.tick(at: 1), [])
        XCTAssertFalse(r.needsClock)
    }

    func testDoubleTapNeverRightClicks() {
        var r = GestureRecognizer()
        var events = tap(&r, at: 0)
        events += tap(&r, at: 0.2, x: 110)
        events += r.tick(at: 1)
        XCTAssertEqual(events, [.sessionEnded, .missionControl, .sessionEnded])
    }

    func testAnotherGestureDeliversThePendingRightClickFirst() {
        var r = GestureRecognizer()
        _ = tap(&r, at: 0)
        _ = r.handle(frame([(1, 400, 400)], at: 0.15))

        XCTAssertEqual(r.handle(empty(at: 0.2)), [
            .rightClick(at: CGPoint(x: 150, y: 100)),
            .leftClick(at: CGPoint(x: 400, y: 400)), .sessionEnded,
        ])
        XCTAssertEqual(r.tick(at: 1), [])
    }

    func testForceReleaseDropsAPendingRightClick() {
        var r = GestureRecognizer()
        _ = tap(&r, at: 0)
        XCTAssertEqual(r.forceRelease(), [])
        XCTAssertEqual(r.tick(at: 1), [])
    }

    func testThreeFingerPanSwitchesDesktops() {
        var r = GestureRecognizer()
        _ = r.handle(frame([(1, 100, 100), (2, 200, 100), (3, 300, 100)], at: 0))

        XCTAssertEqual(r.handle(frame([(1, 200, 100), (2, 300, 100), (3, 400, 100)], at: 0.1)), [.swipeRight])
        XCTAssertEqual(r.handle(empty(at: 0.2)), [.sessionEnded])
    }

    func testTwoFingerDoubleTapOpensMissionControlOncePerPair() {
        var r = GestureRecognizer()
        XCTAssertEqual(tap(&r, at: 0), [.sessionEnded])
        XCTAssertEqual(tap(&r, at: 0.2, x: 110), [.missionControl, .sessionEnded])
        XCTAssertEqual(r.handle(empty(at: 0.35)), [])
        XCTAssertEqual(tap(&r, at: 0.4), [.sessionEnded])
        XCTAssertEqual(tap(&r, at: 0.6), [.missionControl, .sessionEnded])
    }

    func testDoubleTapSurvivesStaggeredArrivalAndLift() {
        var r = GestureRecognizer()
        _ = r.handle(frame([(1, 100, 100)], at: 0))
        _ = r.handle(two(at: 0.02))
        XCTAssertEqual(r.handle(frame([(2, 200, 100)], at: 0.07)), [])
        XCTAssertEqual(r.handle(empty(at: 0.09)), [.sessionEnded])
        _ = r.handle(frame([(7, 110, 100)], at: 0.2))
        _ = r.handle(two(at: 0.22, x: 110, ids: [7, 8]))
        XCTAssertEqual(r.handle(frame([(7, 112, 101)], at: 0.26)), [])
        XCTAssertEqual(r.handle(empty(at: 0.29)), [.missionControl, .sessionEnded])
    }

    func testDoubleTapRejectsAnExpiredOrDistantSecondTap() {
        for (time, x): (TimeInterval, CGFloat) in [(0.6, 100), (0.2, 300)] {
            var r = GestureRecognizer()
            _ = tap(&r, at: 0)
            // The first tap was a lone tap after all: its right-click, not Mission Control.
            XCTAssertEqual(tap(&r, at: time, x: x), [.rightClick(at: CGPoint(x: 150, y: 100)), .sessionEnded])
        }
    }

    func testSecondTapMayLastForTheNormalTapWindow() {
        var r = GestureRecognizer()
        _ = tap(&r, at: 0)
        _ = r.handle(two(at: 0.4))

        XCTAssertEqual(r.handle(empty(at: 0.65)), [.missionControl, .sessionEnded])
    }

    func testTwoFingerHoldIsNotADoubleTap() {
        var r = GestureRecognizer()
        _ = tap(&r, at: 0)
        _ = r.handle(two(at: 0.2))

        XCTAssertEqual(r.handle(empty(at: 0.6)), [.rightClick(at: CGPoint(x: 150, y: 100)), .sessionEnded])
        XCTAssertEqual(tap(&r, at: 0.7), [.sessionEnded])
    }

    func testIndividualFingerMovementCancelsTheTapEvenWithAStillCentroid() {
        var r = GestureRecognizer()
        _ = tap(&r, at: 0)
        _ = r.handle(two(at: 0.2))

        XCTAssertEqual(r.handle(frame([(1, 70, 100), (2, 230, 100)], at: 0.25)), [
            .rightClick(at: CGPoint(x: 150, y: 100)),
            .pinch(scale: 1.6, at: CGPoint(x: 150, y: 100)),
        ])
        XCTAssertEqual(r.handle(empty(at: 0.3)), [.sessionEnded])
        XCTAssertEqual(tap(&r, at: 0.4), [.sessionEnded])
    }

    func testMovingTheLastFingerDuringLiftCancelsTheDoubleTap() {
        var r = GestureRecognizer()
        _ = tap(&r, at: 0)
        _ = r.handle(two(at: 0.2))

        XCTAssertEqual(r.handle(frame([(1, 100, 100)], at: 0.25)), [])
        XCTAssertEqual(r.handle(frame([(1, 140, 100)], at: 0.27)), [.rightClick(at: CGPoint(x: 150, y: 100))])
        XCTAssertEqual(r.handle(empty(at: 0.3)), [.sessionEnded])
        XCTAssertEqual(tap(&r, at: 0.4), [.sessionEnded])
    }

    func testContactReplacementWithinATapCancelsDoubleTap() {
        var r = GestureRecognizer()
        _ = tap(&r, at: 0)
        _ = r.handle(two(at: 0.2))
        XCTAssertEqual(r.handle(two(at: 0.25, ids: [7, 8])), [.rightClick(at: CGPoint(x: 150, y: 100))])
        XCTAssertEqual(r.handle(empty(at: 0.3)), [.sessionEnded])
        XCTAssertEqual(tap(&r, at: 0.4), [.sessionEnded])
    }

    func testDuplicateContactIDsDoNotCountAsADoubleTap() {
        var r = GestureRecognizer()
        _ = tap(&r, at: 0)
        _ = r.handle(two(at: 0.2, ids: [1, 1]))

        XCTAssertEqual(r.handle(empty(at: 0.3)), [.sessionEnded])
        XCTAssertEqual(tap(&r, at: 0.4), [.sessionEnded])
    }

    func testThirdFingerCancelsDoubleTapUntilFullLift() {
        var r = GestureRecognizer()
        _ = tap(&r, at: 0)
        _ = r.handle(two(at: 0.2))
        _ = r.handle(frame([(1, 100, 100), (2, 200, 100), (3, 300, 100)], at: 0.23))
        _ = r.handle(two(at: 0.26))

        XCTAssertEqual(r.handle(empty(at: 0.3)), [.sessionEnded])
        XCTAssertEqual(tap(&r, at: 0.4), [.sessionEnded])
    }

    func testInterveningOneFingerClickScrollOrHoldCancelsDoubleTap() {
        for action in ["click", "scroll", "hold"] {
            var r = GestureRecognizer()
            _ = tap(&r, at: 0)
            _ = r.handle(frame([(1, 100, 100)], at: 0.15))
            if action == "scroll" {
                _ = r.handle(frame([(1, 140, 100)], at: 0.18))
            }
            if action == "hold" {
                _ = r.tick(at: 0.8)
                _ = r.handle(empty(at: 0.85))
                XCTAssertEqual(tap(&r, at: 0.9), [.sessionEnded])
            } else {
                _ = r.handle(empty(at: 0.2))
                XCTAssertEqual(tap(&r, at: 0.25), [.sessionEnded])
            }
        }
    }

    func testTwoFingerMovementClearsAnEarlierTap() {
        var r = GestureRecognizer()
        _ = tap(&r, at: 0)
        _ = r.handle(two(at: 0.15))
        XCTAssertEqual(r.handle(two(at: 0.2, x: 180)), [
            .rightClick(at: CGPoint(x: 150, y: 100)),
            .scroll(dx: 80, dy: 0, at: CGPoint(x: 230, y: 100)),
        ])
        XCTAssertEqual(r.handle(empty(at: 0.25)), [.sessionEnded])
        XCTAssertEqual(tap(&r, at: 0.3), [.sessionEnded])
    }

    func testForceReleaseClearsAPendingTapEvenWhileIdle() {
        var r = GestureRecognizer()
        _ = tap(&r, at: 0)

        XCTAssertEqual(r.forceRelease(), [])
        XCTAssertEqual(tap(&r, at: 0.2), [.sessionEnded])
        _ = r.handle(two(at: 0.4))
        XCTAssertEqual(r.forceRelease(), [.sessionEnded])
        XCTAssertEqual(tap(&r, at: 0.5), [.sessionEnded])
    }

    func testOutOfOrderTimesCannotCompleteADoubleTap() {
        var r = GestureRecognizer()
        _ = tap(&r, at: 1)
        _ = r.handle(two(at: 0.8))
        XCTAssertEqual(r.handle(empty(at: 0.9)), [.sessionEnded])

        _ = r.handle(two(at: 1.2))
        XCTAssertEqual(r.handle(empty(at: 1.15)), [.sessionEnded])
        XCTAssertEqual(tap(&r, at: 1.3), [.sessionEnded])
    }

    func testContactReplacementCannotDragFromTheWrongPlace() {
        var r = GestureRecognizer()
        _ = r.handle(frame([(1, 100, 100)], at: 0))
        _ = r.handle(frame([(1, 130, 100)], at: 0.05))

        // Mid-drag: release where the real finger was, never jump to the new contact.
        XCTAssertEqual(r.handle(frame([(7, 800, 400)], at: 0.1)), [
            .dragEnded(at: CGPoint(x: 130, y: 100)),
        ])
        XCTAssertEqual(r.handle(frame([(7, 810, 425)], at: 0.15)), [])
        XCTAssertEqual(r.handle(empty(at: 0.2)), [.sessionEnded])

        // Before any movement: no press at all.
        _ = r.handle(frame([(1, 100, 100)], at: 1))
        XCTAssertEqual(r.handle(frame([(7, 800, 400)], at: 1.05)), [])
        XCTAssertEqual(r.handle(frame([(7, 840, 425)], at: 1.1)), [])
        XCTAssertEqual(r.handle(empty(at: 1.15)), [.sessionEnded])
    }

    func testASecondFingerAfterScrollingCannotBecomeADoubleTap() {
        var r = GestureRecognizer()
        _ = tap(&r, at: 0)
        _ = r.handle(frame([(1, 100, 100)], at: 0.15))
        _ = r.handle(frame([(1, 130, 100)], at: 0.18))
        _ = r.handle(two(at: 0.2))

        XCTAssertEqual(r.handle(empty(at: 0.25)), [.sessionEnded])
        XCTAssertEqual(tap(&r, at: 0.3), [.sessionEnded])
    }
}
