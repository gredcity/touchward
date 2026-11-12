import CoreGraphics
import XCTest
@testable import touchward

final class CursorReturnTargetTests: XCTestCase {
    /// The CreateBoard is the only (main) display. Returning "home" meant warping to the
    /// centre of the very screen just touched, after every lift.
    func testNoReturnWhenTouchscreenIsTheMainDisplay() {
        let main = CGMainDisplayID()
        XCTAssertNil(TouchPipeline.cursorReturnTarget(touchDisplay: main, mainDisplay: main))
    }

    func testReturnsToMainCentreWhenTouchscreenIsSecondary() {
        let main = CGMainDisplayID()
        XCTAssertEqual(TouchPipeline.cursorReturnTarget(touchDisplay: main &+ 1, mainDisplay: main),
                       DisplayRegistry.centre(of: main))
    }
}
