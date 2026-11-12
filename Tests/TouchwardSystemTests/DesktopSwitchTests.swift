import CoreGraphics
import XCTest
@testable import touchward

final class DesktopSwitchTests: XCTestCase {
    func testDesktopArrowUsesHIDSourceAndPhysicalArrowFlagsOnBothEdges() throws {
        for right in [false, true] {
            let (down, up) = try XCTUnwrap(EventSynthesizer.desktopSwitchEvents(right: right))
            XCTAssertEqual(down.type, .keyDown)
            XCTAssertEqual(up.type, .keyUp)
            for event in [down, up] {
                XCTAssertEqual(event.getIntegerValueField(.keyboardEventKeycode), right ? 124 : 123)
                XCTAssertEqual(event.getIntegerValueField(.eventSourceStateID),
                               Int64(CGEventSourceStateID.hidSystemState.rawValue))
                XCTAssertTrue(event.flags.contains(.maskControl))
                XCTAssertTrue(event.flags.contains(.maskSecondaryFn))
                XCTAssertFalse(event.flags.contains(.maskCommand))
                XCTAssertEqual(event.getIntegerValueField(.eventSourceUserData), EventSynthesizer.marker)
            }
        }
    }
}
