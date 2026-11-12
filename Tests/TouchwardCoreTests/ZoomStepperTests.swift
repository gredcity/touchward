import CoreGraphics
import XCTest
@testable import TouchwardCore

final class ZoomStepperTests: XCTestCase {
    func testSmallMovementsAccumulateIntoAShortcut() {
        var stepper = ZoomStepper()
        XCTAssertEqual(stepper.consume(scale: 1.05, at: 0), 0)
        XCTAssertEqual(stepper.consume(scale: 1.05, at: 0.2), 1)
    }

    func testSessionResetCannotCarryZoomIntoTheNextGesture() {
        var stepper = ZoomStepper()
        _ = stepper.consume(scale: 1.09, at: 0)
        stepper.reset()
        XCTAssertEqual(stepper.consume(scale: 1.02, at: 0.2), 0)
    }

    func testFastSpreadProducesOneShortcutInsteadOfABurst() {
        var stepper = ZoomStepper()
        XCTAssertEqual(stepper.consume(scale: 4, at: 0), 1)
    }

    func testRapidUpdatesAreLimitedAndDoNotQueueCatchUpAfterMotionStops() {
        var stepper = ZoomStepper()
        XCTAssertEqual(stepper.consume(scale: 2, at: 0), 1)
        XCTAssertEqual(stepper.consume(scale: 2, at: 0.01), 0)
        XCTAssertEqual(stepper.consume(scale: 0.5, at: 0.02), 0)
        XCTAssertEqual(stepper.consume(scale: 1, at: 0.2), 0)
        XCTAssertEqual(stepper.consume(scale: 1.01, at: 0.3), 0)
        XCTAssertEqual(stepper.consume(scale: 1.2, at: 0.5), 1)
    }

    func testOneSecondOfNoisyInputCannotFloodTheApplication() {
        var stepper = ZoomStepper()
        var shortcuts = 0
        for index in 0..<200 {
            shortcuts += abs(stepper.consume(scale: index.isMultiple(of: 2) ? 2 : 0.5,
                                             at: Double(index) * 0.005))
        }
        XCTAssertGreaterThan(shortcuts, 0)
        XCTAssertLessThanOrEqual(shortcuts, 9)
    }

    func testFullLiftResetClearsThePreviousGestureRateLimit() {
        var stepper = ZoomStepper()
        _ = stepper.consume(scale: 2, at: 0)
        stepper.reset()
        XCTAssertEqual(stepper.consume(scale: 1.2, at: 0.01), 1)
    }

    func testInvalidRatiosProduceNoShortcut() {
        var stepper = ZoomStepper()
        for value: CGFloat in [0, -1, .nan, .infinity] {
            XCTAssertEqual(stepper.consume(scale: value, at: 0), 0)
        }
    }
}
