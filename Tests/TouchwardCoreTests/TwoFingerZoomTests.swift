import CoreGraphics
import XCTest
@testable import TouchwardCore

final class TwoFingerZoomTests: XCTestCase {
    private func hand(spread: CGFloat, x: CGFloat = 500, y: CGFloat = 500,
                      ids: [UInt8] = [1, 2], at time: TimeInterval) -> MappedFrame {
        MappedFrame(contacts: ids.enumerated().map { index, id in
            MappedContact(id: id, point: CGPoint(x: x + (index == 0 ? -spread : spread), y: y))
        }, time: time)
    }

    private func end(at time: TimeInterval) -> MappedFrame {
        MappedFrame(contacts: [], time: time)
    }

    func testSpreadingTwoFingersZoomsIn() {
        var r = GestureRecognizer()
        _ = r.handle(hand(spread: 100, at: 0))
        XCTAssertEqual(r.handle(hand(spread: 150, at: 0.05)), [
            .pinch(scale: 1.5, at: CGPoint(x: 500, y: 500)),
        ])
    }

    func testPinchingTwoFingersZoomsOut() {
        var r = GestureRecognizer()
        _ = r.handle(hand(spread: 200, at: 0))
        XCTAssertEqual(r.handle(hand(spread: 100, at: 0.05)), [
            .pinch(scale: 0.5, at: CGPoint(x: 500, y: 500)),
        ])
    }

    func testPinchWorksWithOneFingerStationary() {
        var r = GestureRecognizer()
        _ = r.handle(hand(spread: 100, at: 0))
        // The left contact stays at x=400; only the right contact moves.
        XCTAssertEqual(r.handle(hand(spread: 150, x: 550, at: 0.05)), [
            .pinch(scale: 1.5, at: CGPoint(x: 550, y: 500)),
        ])
    }

    func testZoomReportsPerFrameRatiosAndCanReverseDirection() {
        var r = GestureRecognizer()
        _ = r.handle(hand(spread: 100, at: 0))
        _ = r.handle(hand(spread: 200, at: 0.05))
        XCTAssertEqual(r.handle(hand(spread: 300, at: 0.10)), [
            .pinch(scale: 1.5, at: CGPoint(x: 500, y: 500)),
        ])
        XCTAssertEqual(r.handle(hand(spread: 150, at: 0.15)), [
            .pinch(scale: 0.5, at: CGPoint(x: 500, y: 500)),
        ])
        XCTAssertEqual(r.handle(hand(spread: 150, at: 0.20)), [])
    }

    func testPinchStaysZoomWhenTheHandThenMoves() {
        var r = GestureRecognizer()
        _ = r.handle(hand(spread: 100, at: 0))
        _ = r.handle(hand(spread: 150, at: 0.05))
        XCTAssertEqual(r.handle(hand(spread: 180, x: 700, y: 800, at: 0.10)), [
            .pinch(scale: 1.2, at: CGPoint(x: 700, y: 800)),
        ])
        XCTAssertEqual(r.handle(hand(spread: 180, x: 800, y: 900, at: 0.15)), [])
    }

    func testScrollStaysScrollWhenTheFingersLaterSpread() {
        var r = GestureRecognizer()
        _ = r.handle(hand(spread: 100, at: 0))
        _ = r.handle(hand(spread: 100, y: 520, at: 0.05))
        XCTAssertEqual(r.handle(hand(spread: 180, y: 540, at: 0.10)), [
            .scroll(dx: 0, dy: 20, at: CGPoint(x: 500, y: 540)),
        ])
    }

    func testLostOrReplacedContactStopsZoomUntilFullLift() {
        for missing in [hand(spread: 200, ids: [1], at: 0.10),
                        hand(spread: 200, ids: [7, 8], at: 0.10)] {
            var r = GestureRecognizer()
            _ = r.handle(hand(spread: 100, at: 0))
            _ = r.handle(hand(spread: 150, at: 0.05))
            XCTAssertEqual(r.handle(missing), [])
            let ids: [UInt8] = missing.contacts.count == 1 ? [1, 2] : [7, 8]
            XCTAssertEqual(r.handle(hand(spread: 200, ids: ids, at: 0.15)), [])
            XCTAssertEqual(r.handle(hand(spread: 100, ids: ids, at: 0.20)), [])
            XCTAssertEqual(r.handle(end(at: 0.25)), [.sessionEnded])
            _ = r.handle(hand(spread: 100, ids: ids, at: 0.30))
            XCTAssertEqual(r.handle(hand(spread: 150, ids: ids, at: 0.35)), [
                .pinch(scale: 1.5, at: CGPoint(x: 500, y: 500)),
            ])
        }
    }

    func testZeroSpreadReanchorsBeforeZooming() {
        var r = GestureRecognizer()
        _ = r.handle(hand(spread: 0, at: 0))
        XCTAssertEqual(r.handle(hand(spread: 100, at: 0.05)), [])
        XCTAssertEqual(r.handle(hand(spread: 150, at: 0.10)), [
            .pinch(scale: 1.5, at: CGPoint(x: 500, y: 500)),
        ])
        XCTAssertEqual(r.handle(hand(spread: 0, at: 0.15)), [])
        XCTAssertEqual(r.handle(hand(spread: 200, at: 0.20)), [])
        XCTAssertEqual(r.handle(hand(spread: 100, at: 0.25)), [])
        XCTAssertEqual(r.handle(end(at: 0.30)), [.sessionEnded])
    }

    func testSmallRecognizedPinchCannotCompleteOrPrimeMissionControl() {
        for hasEarlierTap in [false, true] {
            var r = GestureRecognizer()
            if hasEarlierTap {
                _ = r.handle(hand(spread: 50, at: 0))
                _ = r.handle(end(at: 0.05))
            }
            _ = r.handle(hand(spread: 50, at: 0.10))
            let earlier: [GestureEvent] = hasEarlierTap ? [.rightClick(at: CGPoint(x: 500, y: 500))] : []
            XCTAssertEqual(r.handle(hand(spread: 56, at: 0.15)), earlier + [
                .pinch(scale: 1.12, at: CGPoint(x: 500, y: 500)),
            ])
            XCTAssertEqual(r.handle(end(at: 0.20)), [.sessionEnded])
            _ = r.handle(hand(spread: 50, at: 0.25))
            XCTAssertEqual(r.handle(end(at: 0.30)), [.sessionEnded])
        }
    }

    func testRemainingFingerCannotScrollOrClickAfterZoom() {
        var r = GestureRecognizer()
        _ = r.handle(hand(spread: 100, at: 0))
        _ = r.handle(hand(spread: 150, at: 0.05))
        XCTAssertEqual(r.handle(hand(spread: 100, y: 700, ids: [1], at: 0.10)), [])
        XCTAssertEqual(r.handle(end(at: 0.15)), [.sessionEnded])
        // A new touch session can scroll normally after the pinch ends.
        _ = r.handle(hand(spread: 100, at: 0.20))
        XCTAssertEqual(r.handle(hand(spread: 100, y: 520, at: 0.25)), [
            .scroll(dx: 0, dy: 20, at: CGPoint(x: 500, y: 520)),
        ])
    }

    func testAddingThirdFingerDuringPinchStopsUntilFullLift() {
        func three(spread: CGFloat, x: CGFloat, at time: TimeInterval) -> MappedFrame {
            MappedFrame(contacts: [
                MappedContact(id: 1, point: CGPoint(x: x - spread, y: 500)),
                MappedContact(id: 2, point: CGPoint(x: x + spread, y: 500)),
                MappedContact(id: 3, point: CGPoint(x: x, y: 500)),
            ], time: time)
        }
        var r = GestureRecognizer()
        _ = r.handle(hand(spread: 100, at: 0))
        _ = r.handle(hand(spread: 150, at: 0.05))
        XCTAssertEqual(r.handle(three(spread: 150, x: 500, at: 0.10)), [])
        XCTAssertEqual(r.handle(three(spread: 150, x: 570, at: 0.15)), [])
        XCTAssertEqual(r.handle(three(spread: 180, x: 570, at: 0.20)), [])
        XCTAssertEqual(r.handle(end(at: 0.25)), [.sessionEnded])
    }

    func testSmallBackAndForthJitterCannotReverseACommittedPinch() {
        var r = GestureRecognizer()
        _ = r.handle(hand(spread: 30, at: 0))
        _ = r.handle(hand(spread: 36, at: 0.05))
        // Six points of jitter at a small separation used to alternate 1.2x / 0.833x.
        for (index, spread) in [30.0, 36, 31, 35, 30, 36].enumerated() {
            XCTAssertEqual(r.handle(hand(spread: spread, at: 0.10 + Double(index) * 0.02)), [])
        }
    }

    func testNearlyTouchingFingersCannotProduceExtremeZoomRatios() {
        var r = GestureRecognizer()
        _ = r.handle(hand(spread: 100, at: 0))
        _ = r.handle(hand(spread: 80, at: 0.05))
        for (index, spread) in [10.0, 4, 12, 5, 80].enumerated() {
            XCTAssertEqual(r.handle(hand(spread: spread, at: 0.10 + Double(index) * 0.02)), [])
        }
        XCTAssertEqual(r.handle(end(at: 0.25)), [.sessionEnded])
    }

    func testLiftingAFingerStopsZoomEvenIfTheControllerReportsItAgain() {
        var r = GestureRecognizer()
        _ = r.handle(hand(spread: 100, at: 0))
        _ = r.handle(hand(spread: 150, at: 0.05))
        XCTAssertEqual(r.handle(hand(spread: 150, ids: [1], at: 0.10)), [])
        XCTAssertEqual(r.handle(hand(spread: 150, at: 0.15)), [])
        XCTAssertEqual(r.handle(hand(spread: 300, at: 0.20)), [])
        XCTAssertEqual(r.handle(end(at: 0.25)), [.sessionEnded])
    }

    func testCloseTogetherFingersCanStillScroll() {
        var r = GestureRecognizer()
        _ = r.handle(hand(spread: 10, at: 0))
        XCTAssertEqual(r.handle(hand(spread: 10, y: 530, at: 0.05)), [
            .scroll(dx: 0, dy: 30, at: CGPoint(x: 500, y: 530)),
        ])
    }

    func testRejectedClosePinchCannotAccumulateAScrollJump() {
        var r = GestureRecognizer()
        _ = r.handle(hand(spread: 2, x: 500, at: 0))
        XCTAssertEqual(r.handle(hand(spread: 8, x: 506, at: 0.05)), [])
        XCTAssertEqual(r.handle(hand(spread: 2, x: 512, at: 0.10)), [])
        XCTAssertEqual(r.handle(hand(spread: 2, x: 532, at: 0.15)), [
            .scroll(dx: 20, dy: 0, at: CGPoint(x: 532, y: 500)),
        ])
    }

    func testReorderedContactsKeepZoomProgress() {
        var r = GestureRecognizer()
        _ = r.handle(hand(spread: 100, at: 0))
        let moved = hand(spread: 150, at: 0.05)
        XCTAssertEqual(r.handle(MappedFrame(contacts: moved.contacts.reversed(), time: moved.time)), [
            .pinch(scale: 1.5, at: CGPoint(x: 500, y: 500)),
        ])
    }
}
