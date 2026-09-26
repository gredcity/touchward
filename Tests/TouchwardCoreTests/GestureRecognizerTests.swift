import CoreGraphics
import XCTest
@testable import TouchwardCore

private func frame(_ points: [(UInt8, CGFloat, CGFloat)], at time: TimeInterval) -> MappedFrame {
    MappedFrame(
        contacts: points.map { MappedContact(id: $0.0, point: CGPoint(x: $0.1, y: $0.2)) },
        time: time
    )
}

private func empty(at time: TimeInterval) -> MappedFrame {
    MappedFrame(contacts: [], time: time)
}

final class GestureRecognizerTests: XCTestCase {

    // MARK: one finger

    func testQuickTapEmitsLeftClickOnLift() {
        var r = GestureRecognizer()

        XCTAssertEqual(r.handle(frame([(1, 100, 100)], at: 0)), [],
                       "a touch alone is not yet a gesture — it could still become a drag")
        XCTAssertEqual(r.handle(empty(at: 0.1)),
                       [.leftClick(at: CGPoint(x: 100, y: 100)), .sessionEnded])
    }

    func testSlowLiftIsNotATap() {
        var r = GestureRecognizer()
        _ = r.handle(frame([(1, 100, 100)], at: 0))

        // Holding arms the drag; lifting without movement chooses a right click.
        _ = r.handle(frame([(1, 100, 100)], at: 0.7))
        XCTAssertEqual(r.handle(empty(at: 0.8)), [.rightClick(at: CGPoint(x: 100, y: 100)), .sessionEnded])
    }

    func testLongPressDefersRightClickUntilLift() {
        var r = GestureRecognizer()
        _ = r.handle(frame([(1, 300, 400)], at: 0))

        XCTAssertEqual(r.handle(frame([(1, 300, 400)], at: 0.65)), [])
        XCTAssertEqual(r.handle(frame([(1, 300, 400)], at: 0.9)), [],
                       "long press must not repeat while the finger stays down")
        XCTAssertEqual(r.handle(empty(at: 1.0)), [.rightClick(at: CGPoint(x: 300, y: 400)), .sessionEnded])
    }

    func testMovingBeforeTheLongPressCancelsIt() {
        var r = GestureRecognizer()
        _ = r.handle(frame([(1, 100, 100)], at: 0))
        _ = r.handle(frame([(1, 300, 100)], at: 0.1))

        let events = r.handle(frame([(1, 320, 100)], at: 0.7))
        XCTAssertFalse(events.contains { if case .rightClick = $0 { return true } else { return false } })
    }

    func testDragEmitsBeganFromTheOriginalTouchPoint() {
        var r = GestureRecognizer()
        _ = r.handle(frame([(1, 100, 100)], at: 0))

        XCTAssertEqual(r.handle(frame([(1, 160, 100)], at: 0.65)),
                       [.dragBegan(at: CGPoint(x: 100, y: 100)),
                        .dragMoved(to: CGPoint(x: 160, y: 100))])
        XCTAssertEqual(r.handle(frame([(1, 200, 100)], at: 0.7)),
                       [.dragMoved(to: CGPoint(x: 200, y: 100))])
        XCTAssertEqual(r.handle(empty(at: 0.75)),
                       [.dragEnded(at: CGPoint(x: 200, y: 100)), .sessionEnded])
    }

    func testTinyJitterDoesNotStartADrag() {
        var r = GestureRecognizer()
        _ = r.handle(frame([(1, 100, 100)], at: 0))

        XCTAssertEqual(r.handle(frame([(1, 103, 102)], at: 0.05)), [],
                       "movement under the threshold is noise, not intent")
        XCTAssertEqual(r.handle(empty(at: 0.1)),
                       [.leftClick(at: CGPoint(x: 100, y: 100)), .sessionEnded])
    }

    // MARK: scrolling and two fingers

    func testOneFingerMovementEmitsScrollDisplacement() {
        var r = GestureRecognizer()
        XCTAssertEqual(r.handle(frame([(1, 100, 100)], at: 0)), [])

        // The finger moves down 20pt.
        let events = r.handle(frame([(1, 100, 120)], at: 0.05))
        XCTAssertEqual(events, [.scroll(dx: 0, dy: 20, at: CGPoint(x: 100, y: 120))])
    }

    func testScrollDeltaIsPerFrameNotCumulative() {
        var r = GestureRecognizer()
        _ = r.handle(frame([(1, 100, 100)], at: 0))
        _ = r.handle(frame([(1, 100, 120)], at: 0.05))

        XCTAssertEqual(r.handle(frame([(1, 100, 130)], at: 0.1)),
                       [.scroll(dx: 0, dy: 10, at: CGPoint(x: 100, y: 130))],
                       "a cumulative delta would report 30 here and scroll far too fast")
    }

    func testHorizontalScrollIsReported() {
        var r = GestureRecognizer()
        _ = r.handle(frame([(1, 100, 100)], at: 0))

        XCTAssertEqual(r.handle(frame([(1, 145, 100)], at: 0.05)),
                       [.scroll(dx: 45, dy: 0, at: CGPoint(x: 145, y: 100))])
    }

    func testTwoFingerSingleTapDoesNotRightClick() {
        var r = GestureRecognizer()
        _ = r.handle(frame([(1, 100, 100), (2, 200, 100)], at: 0))

        XCTAssertEqual(r.handle(empty(at: 0.1)),
                       [.sessionEnded])
    }

    /// Landing a second finger mid-gesture must not leave a stray left click behind.
    func testSecondFingerCancelsThePendingSingleFingerTap() {
        var r = GestureRecognizer()
        _ = r.handle(frame([(1, 100, 100)], at: 0))
        _ = r.handle(frame([(1, 100, 100), (2, 200, 100)], at: 0.05))

        let events = r.handle(empty(at: 0.1))
        XCTAssertFalse(events.contains { if case .leftClick = $0 { return true } else { return false } })
    }

    /// A drag in progress must be closed out properly rather than abandoned.
    func testSecondFingerDuringADragEndsTheDrag()  {
        var r = GestureRecognizer()
        _ = r.handle(frame([(1, 100, 100)], at: 0))
        _ = r.handle(frame([(1, 200, 100)], at: 0.65))

        let events = r.handle(frame([(1, 200, 100), (2, 300, 100)], at: 0.7))
        XCTAssertEqual(events, [.dragEnded(at: CGPoint(x: 200, y: 100))])
    }

    // MARK: session

    func testEmptyFramesWhileIdleProduceNothing() {
        var r = GestureRecognizer()
        XCTAssertEqual(r.handle(empty(at: 0)), [])
        XCTAssertEqual(r.handle(empty(at: 1)), [],
                       "sessionEnded must fire once per session, not on every idle frame")
    }
}
