import CoreGraphics
import XCTest
@testable import TouchwardCore

final class TwoFingerScrollTests: XCTestCase {
    private func hand(x: CGFloat = 100, y: CGFloat = 100,
                      ids: [UInt8] = [1, 2], at time: TimeInterval) -> MappedFrame {
        MappedFrame(contacts: ids.enumerated().map { index, id in
            MappedContact(id: id, point: CGPoint(x: x + CGFloat(index) * 100, y: y))
        }, time: time)
    }

    func testTwoFingersScrollBothAxesWithPerFrameDeltas() {
        var r = GestureRecognizer()
        _ = r.handle(hand(at: 0))
        XCTAssertEqual(r.handle(hand(x: 130, y: 120, at: 0.05)), [
            .scroll(dx: 30, dy: 20, at: CGPoint(x: 180, y: 120)),
        ])
        XCTAssertEqual(r.handle(hand(x: 125, y: 150, at: 0.1)), [
            .scroll(dx: -5, dy: 30, at: CGPoint(x: 175, y: 150)),
        ])
        XCTAssertEqual(r.handle(hand(x: 125, y: 150, at: 0.15)), [])
        XCTAssertEqual(r.handle(hand(ids: [], at: 0.2)), [.sessionEnded])
    }

    func testLongHorizontalTwoFingerPanScrollsInsteadOfSwitchingDesktops() {
        var r = GestureRecognizer()
        _ = r.handle(hand(at: 0))
        XCTAssertEqual(r.handle(hand(x: 300, at: 0.1)), [
            .scroll(dx: 200, dy: 0, at: CGPoint(x: 350, y: 100)),
        ])
    }

    func testTwoFingerScrollStartsAfterJitterAndKeepsSmallDeltas() {
        var r = GestureRecognizer()
        _ = r.handle(hand(at: 0))
        XCTAssertEqual(r.handle(hand(y: 104, at: 0.02)), [])
        XCTAssertEqual(r.handle(hand(y: 111, at: 0.04)), [
            .scroll(dx: 0, dy: 11, at: CGPoint(x: 150, y: 111)),
        ])
        XCTAssertEqual(r.handle(hand(y: 111.5, at: 0.06)), [
            .scroll(dx: 0, dy: 0.5, at: CGPoint(x: 150, y: 111.5)),
        ])
    }

    func testLostOrReplacedContactReanchorsWithoutAScrollJump() {
        for missing in [hand(x: 800, ids: [1], at: 0.1),
                        hand(x: 800, ids: [7, 8], at: 0.1)] {
            var r = GestureRecognizer()
            _ = r.handle(hand(at: 0))
            _ = r.handle(hand(y: 120, at: 0.05))
            XCTAssertEqual(r.handle(missing), [])
            let ids: [UInt8] = missing.contacts.count == 1 ? [1, 2] : [7, 8]
            XCTAssertEqual(r.handle(hand(x: 800, ids: ids, at: 0.15)), [])
            XCTAssertEqual(r.handle(hand(x: 800, y: 125, ids: ids, at: 0.2)), [
                .scroll(dx: 0, dy: 25, at: CGPoint(x: 850, y: 125)),
            ])
        }
    }

    func testReorderedContactsKeepScrollProgress() {
        var r = GestureRecognizer()
        _ = r.handle(hand(at: 0))
        let moved = hand(y: 120, at: 0.05)
        XCTAssertEqual(r.handle(MappedFrame(contacts: moved.contacts.reversed(), time: moved.time)), [
            .scroll(dx: 0, dy: 20, at: CGPoint(x: 150, y: 120)),
        ])
    }

    func testRemainingFingerCannotScrollOrClickAfterTwoFingerScroll() {
        var r = GestureRecognizer()
        _ = r.handle(hand(at: 0))
        _ = r.handle(hand(y: 120, at: 0.05))
        XCTAssertEqual(r.handle(hand(y: 200, ids: [1], at: 0.1)), [])
        XCTAssertEqual(r.handle(hand(y: 400, ids: [1], at: 0.15)), [])
        XCTAssertEqual(r.handle(hand(ids: [], at: 0.2)), [.sessionEnded])
    }

    func testAddingThirdFingerReanchorsBeforeDesktopSwipe() {
        var r = GestureRecognizer()
        _ = r.handle(hand(at: 0))
        _ = r.handle(hand(y: 120, at: 0.05))
        XCTAssertEqual(r.handle(hand(x: 800, ids: [1, 2, 3], at: 0.1)), [])
        XCTAssertEqual(r.handle(hand(x: 730, ids: [1, 2, 3], at: 0.15)), [.swipeLeft])
        XCTAssertEqual(r.handle(hand(x: 1000, ids: [1, 2], at: 0.2)), [])
        XCTAssertEqual(r.handle(hand(ids: [], at: 0.25)), [.sessionEnded])
    }

    func testDuplicateContactsCannotScroll() {
        var r = GestureRecognizer()
        _ = r.handle(hand(ids: [1, 1], at: 0))
        XCTAssertEqual(r.handle(hand(y: 200, ids: [1, 1], at: 0.1)), [])
    }

    func testScrollAtExactThresholdCannotCompleteOrPrimeMissionControl() {
        for hasEarlierTap in [false, true] {
            var r = GestureRecognizer()
            if hasEarlierTap {
                _ = r.handle(hand(at: 0))
                _ = r.handle(hand(ids: [], at: 0.05))
            }
            _ = r.handle(hand(at: 0.1))
            XCTAssertEqual(r.handle(hand(y: 110, at: 0.15)), [
                .scroll(dx: 0, dy: 10, at: CGPoint(x: 150, y: 110)),
            ])
            XCTAssertEqual(r.handle(hand(ids: [], at: 0.2)), [.sessionEnded])
            _ = r.handle(hand(at: 0.25))
            XCTAssertEqual(r.handle(hand(ids: [], at: 0.3)), [.sessionEnded])
        }
    }
}
