import CoreGraphics
import XCTest
@testable import TouchwardCore

final class SwipeGestureTests: XCTestCase {
    private func hand(x: CGFloat = 500, y: CGFloat = 500, spread: CGFloat = 100,
                      ids: [UInt8] = [1, 2], at time: TimeInterval) -> MappedFrame {
        MappedFrame(contacts: ids.enumerated().map { index, id in
            MappedContact(id: id, point: CGPoint(x: x + CGFloat(index - 1) * spread, y: y))
        }, time: time)
    }

    private func empty(at time: TimeInterval) -> MappedFrame {
        MappedFrame(contacts: [], time: time)
    }

    func testTwoFingerLeftSwipeWaitsForDeliberateMovement() {
        var recognizer = GestureRecognizer()
        XCTAssertEqual(recognizer.handle(hand(at: 0)), [])

        XCTAssertEqual(recognizer.handle(hand(x: 450, at: 0.05)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 438, at: 0.1)), [.swipeLeft])
    }

    func testTwoFingerRightSwipeReportsFingerDirection() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(at: 0))

        XCTAssertEqual(recognizer.handle(hand(x: 580, at: 0.1)), [.swipeRight])
    }

    func testSmallPositionAndSpreadJitterProducesNothing() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(at: 0))

        XCTAssertEqual(recognizer.handle(hand(x: 504, y: 503, spread: 103, at: 0.05)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 497, y: 498, spread: 98, at: 0.1)), [])
        XCTAssertEqual(recognizer.handle(empty(at: 0.15)), [.sessionEnded])
    }

    func testVerticalTravelDoesNotSwitchDesktopsOrZoomFromSpreadNoise() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(at: 0))

        XCTAssertEqual(recognizer.handle(hand(y: 525, spread: 103, at: 0.05)), [])
        XCTAssertEqual(recognizer.handle(hand(y: 620, spread: 115, at: 0.1)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 700, y: 520, at: 0.15)), [],
                       "a vertical gesture cannot turn into a desktop swipe mid-session")
    }

    func testDiagonalTravelRequiresHorizontalDominance() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(at: 0))

        XCTAssertEqual(recognizer.handle(hand(x: 580, y: 565, at: 0.1)), [])
    }

    func testCommittedSwipeIgnoresRepeatedFramesAndDirectionReversal() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(at: 0))
        XCTAssertEqual(recognizer.handle(hand(x: 420, at: 0.1)), [.swipeLeft])

        XCTAssertEqual(recognizer.handle(hand(x: 420, at: 0.1)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 300, at: 0.15)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 700, at: 0.2)), [])
        XCTAssertEqual(recognizer.tick(at: 10), [])
    }

    func testCommittedSwipeConsumesAllTrailingContactChangesUntilFullLift() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(at: 0))
        XCTAssertEqual(recognizer.handle(hand(x: 420, at: 0.05)), [.swipeLeft])

        XCTAssertEqual(recognizer.handle(hand(x: 700, ids: [4, 5, 6, 7], at: 0.08)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 800, ids: [5, 6], at: 0.1)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 900, ids: [5, 6], at: 0.12)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 500, ids: [6], at: 0.14)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 100, ids: [8, 9, 10], at: 0.16)), [])
        XCTAssertTrue(recognizer.hasActiveGesture)
        XCTAssertEqual(recognizer.handle(empty(at: 0.18)), [.sessionEnded])
        XCTAssertEqual(recognizer.handle(empty(at: 0.2)), [])
        XCTAssertFalse(recognizer.hasActiveGesture)
    }

    func testStaggeredFingerArrivalStartsSwipeAtTwoFingerFrame() {
        var recognizer = GestureRecognizer()
        XCTAssertEqual(recognizer.handle(hand(ids: [1], at: 0)), [])
        XCTAssertEqual(recognizer.handle(hand(ids: [1, 2], at: 0.02)), [])

        XCTAssertEqual(recognizer.handle(hand(x: 460, at: 0.08)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 420, at: 0.12)), [.swipeLeft])
    }

    func testAddingASecondFingerEndsAnExistingDragBeforeSwiping() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(ids: [1], at: 0))
        XCTAssertEqual(recognizer.tick(at: 0.6), [])
        XCTAssertEqual(recognizer.handle(hand(x: 530, ids: [1], at: 0.65)), [
            .dragBegan(at: CGPoint(x: 400, y: 500)),
            .dragMoved(to: CGPoint(x: 430, y: 500)),
        ])
        XCTAssertEqual(recognizer.handle(hand(at: 0.7)), [
            .dragEnded(at: CGPoint(x: 430, y: 500)),
        ])

        XCTAssertEqual(recognizer.handle(hand(x: 580, at: 0.75)), [.swipeRight])
        XCTAssertEqual(recognizer.handle(empty(at: 0.8)), [.sessionEnded])
    }

    func testReassignedContactIDsCannotTurnACentroidJumpIntoASwipe() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(at: 0))
        XCTAssertEqual(recognizer.handle(hand(x: 460, at: 0.05)), [])

        XCTAssertEqual(recognizer.handle(hand(x: 200, ids: [4, 5], at: 0.1)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 155, ids: [4, 5], at: 0.15)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 130, ids: [4, 5], at: 0.2)), [.swipeLeft])
    }

    func testContactArrayReorderingDoesNotDiscardSwipeProgress() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(at: 0))
        _ = recognizer.handle(hand(x: 460, at: 0.05))
        let moved = hand(x: 430, at: 0.1)
        let reordered = MappedFrame(contacts: moved.contacts.reversed(), time: moved.time)

        XCTAssertEqual(recognizer.handle(reordered), [.swipeLeft])
    }

    func testLostAndReturningContactReanchorsSwipeWithoutJumping() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(at: 0))
        _ = recognizer.handle(hand(x: 470, at: 0.05))

        XCTAssertEqual(recognizer.handle(hand(x: 900, ids: [1], at: 0.1)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 1000, at: 0.15)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 955, at: 0.2)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 930, at: 0.25)), [.swipeLeft])
    }

    func testThreeOrMoreFingersNeverBecomeDesktopSwipesEvenDuringLift() {
        for ids: [UInt8] in [[1, 2, 3], [1, 2, 3, 4], [1, 2, 3, 4, 5]] {
            var recognizer = GestureRecognizer()
            _ = recognizer.handle(hand(ids: ids, at: 0))

            XCTAssertEqual(recognizer.handle(hand(x: 300, ids: ids, at: 0.05)), [])
            XCTAssertEqual(recognizer.handle(hand(x: 300, at: 0.1)), [])
            XCTAssertEqual(recognizer.handle(hand(x: 200, at: 0.15)), [])
            XCTAssertEqual(recognizer.handle(empty(at: 0.2)), [.sessionEnded])
        }
    }

    func testThirdFingerCancelsAnUncommittedSwipe() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(at: 0))
        _ = recognizer.handle(hand(x: 540, at: 0.05))

        XCTAssertEqual(recognizer.handle(hand(x: 540, ids: [1, 2, 3], at: 0.1)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 580, at: 0.15)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 680, at: 0.2)), [])
    }

    func testDuplicateContactIDsDoNotQualifyAsTwoFingers() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(ids: [1, 1], at: 0))

        XCTAssertEqual(recognizer.handle(hand(x: 600, ids: [1, 1], at: 0.1)), [])
    }

    func testSwipeDirectionLocksBeforeAReversalCanSwitchTheOppositeWay() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(at: 0))

        XCTAssertEqual(recognizer.handle(hand(x: 525, at: 0.05)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 400, at: 0.1)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 575, at: 0.15)), [.swipeRight])
    }

    func testHorizontalPanToleratesSpreadNoiseWithoutZooming() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(at: 0))

        XCTAssertEqual(recognizer.handle(hand(x: 510, spread: 103, at: 0.05)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 530, spread: 106, at: 0.1)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 570, spread: 115, at: 0.15)), [.swipeRight])
        XCTAssertEqual(recognizer.handle(hand(x: 600, spread: 200, at: 0.2)), [])
    }

    func testPinchNoiseBeforeHorizontalPanDoesNotClaimTheGesture() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(at: 0))

        XCTAssertEqual(recognizer.handle(hand(x: 504, spread: 107, at: 0.05)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 420, spread: 109, at: 0.1)), [.swipeLeft])
    }

    func testCommittedPinchDoesNotSwitchDesktopsWhenItsCentroidDrifts() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(ids: [1, 2, 3], at: 0))

        XCTAssertEqual(recognizer.handle(hand(x: 505, spread: 150, ids: [1, 2, 3], at: 0.05)), [
            .pinch(scale: 1.5, at: CGPoint(x: 505, y: 500)),
        ])
        XCTAssertEqual(recognizer.handle(hand(x: 700, spread: 150, ids: [1, 2, 3], at: 0.1)), [])
        let events = recognizer.handle(hand(x: 750, spread: 165, ids: [1, 2, 3], at: 0.15))
        guard case .pinch(let scale, let point) = events.first, events.count == 1 else {
            return XCTFail("a pinch stays a pinch until the fingers lift")
        }
        XCTAssertEqual(scale, 1.1, accuracy: 0.001)
        XCTAssertEqual(point, CGPoint(x: 750, y: 500))
    }

    func testSmallPinchStepsAccumulateUntilIntentIsClear() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(ids: [1, 2, 3], at: 0))

        XCTAssertEqual(recognizer.handle(hand(spread: 104, ids: [1, 2, 3], at: 0.05)), [])
        XCTAssertEqual(recognizer.handle(hand(spread: 108, ids: [1, 2, 3], at: 0.1)), [])
        let events = recognizer.handle(hand(spread: 112, ids: [1, 2, 3], at: 0.15))
        guard case .pinch(let scale, _) = events.first, events.count == 1 else {
            return XCTFail("deliberate slow pinching must still zoom")
        }
        XCTAssertEqual(scale, 1.12, accuracy: 0.001)
    }

    func testFullLiftAllowsTheOppositeSwipeInTheNextSession() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(at: 0))
        XCTAssertEqual(recognizer.handle(hand(x: 420, at: 0.1)), [.swipeLeft])
        XCTAssertEqual(recognizer.handle(empty(at: 0.2)), [.sessionEnded])
        XCTAssertEqual(recognizer.handle(hand(at: 0.3)), [])
        XCTAssertEqual(recognizer.handle(hand(x: 580, at: 0.4)), [.swipeRight])
    }

    func testForceReleaseResetsPendingAndCommittedSwipes() {
        for displacement: CGFloat in [25, 80] {
            var recognizer = GestureRecognizer()
            _ = recognizer.handle(hand(at: 0))
            _ = recognizer.handle(hand(x: 500 + displacement, at: 0.1))

            XCTAssertEqual(recognizer.forceRelease(), [.sessionEnded])
            XCTAssertEqual(recognizer.forceRelease(), [])
            XCTAssertFalse(recognizer.hasActiveGesture)
            XCTAssertEqual(recognizer.handle(hand(at: 0.2)), [])
            XCTAssertEqual(recognizer.handle(hand(x: 420, at: 0.3)), [.swipeLeft])
        }
    }

    func testSingleFingerTapAndScrollRecoverAfterSwipeSession() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(hand(at: 0))
        _ = recognizer.handle(hand(x: 420, at: 0.05))
        _ = recognizer.handle(empty(at: 0.1))
        _ = recognizer.handle(hand(ids: [1], at: 0.2))

        XCTAssertEqual(recognizer.handle(empty(at: 0.25)), [
            .leftClick(at: CGPoint(x: 400, y: 500)), .sessionEnded,
        ])
        XCTAssertEqual(recognizer.handle(hand(ids: [1], at: 0.3)), [])
        XCTAssertEqual(recognizer.handle(hand(y: 525, ids: [1], at: 0.35)), [
            .scroll(dx: 0, dy: 25, at: CGPoint(x: 400, y: 525)),
        ])
    }
}
