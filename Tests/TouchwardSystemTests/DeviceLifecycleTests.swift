import XCTest
@testable import touchward

final class DeviceLifecycleTests: XCTestCase {
    func testRemovalReturnsToIOKitBeforeDisconnectAndTeardown() {
        let device = HIDTouchDevice()
        var disconnected = false
        device.onDisconnect = { disconnected = true }

        device.handleRemoval()
        // Closing the manager inside its removal callback caused a libplatform
        // unfair-lock abort on the physical panel's disconnect.
        XCTAssertFalse(disconnected, "Removal must return to IOKit before teardown")

        let deferred = expectation(description: "disconnect handled after callback returns")
        DispatchQueue.main.async {
            XCTAssertTrue(disconnected)
            deferred.fulfill()
        }
        wait(for: [deferred], timeout: 2)
    }
    func testQueuedRemovalDoesNotDisconnectAReplacementSession() {
        let device = HIDTouchDevice()
        var disconnected = false
        device.onDisconnect = { disconnected = true }
        device.handleRemoval()
        // Sleep or a new start invalidates the old session before its queued work runs.
        device.stop()

        let deferred = expectation(description: "old removal discarded")
        DispatchQueue.main.async {
            XCTAssertFalse(disconnected, "An old callback must not tear down a new session")
            deferred.fulfill()
        }
        wait(for: [deferred], timeout: 2)
    }

}
