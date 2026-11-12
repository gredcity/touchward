// Modified for Magic Mouse gestures and session cleanup, 2026-09-26.
import CoreGraphics
import Foundation
import TouchwardCore

/// Wires the pure core to the system layer: bytes in, pointer events out.
final class TouchPipeline {
    private var mapper: CoordinateMapper
    private var recognizer = GestureRecognizer()
    private var palmFilter: PalmFilter
    private let synthesizer: EventSynthesizer
    private let cursorReturn: CursorReturn
    /// Nil when the touchscreen is itself the main display: there is no "home" to return to.
    private var returnTarget: CGPoint?
    private var heartbeat: Timer?

    /// The cursor return exists to get the pointer off a secondary touch panel. When the
    /// panel is the main display, warping to its centre after every lift reads as the
    /// mouse randomly recentring.
    static func cursorReturnTarget(touchDisplay: CGDirectDisplayID,
                                   mainDisplay: CGDirectDisplayID) -> CGPoint? {
        touchDisplay == mainDisplay ? nil : DisplayRegistry.centre(of: mainDisplay)
    }

    private func armCursorReturn() {
        guard let returnTarget else { return }
        cursorReturn.scheduleReturn(to: returnTarget)
    }

    /// Global-coordinate rect of the on-screen keyboard while it is visible.
    /// Touches inside it bypass gesture classification entirely.
    var directTouchRegion: (() -> CGRect?)?
    /// Presses the key under a global point; returns true when a key was actually hit.
    /// Injected rather than synthesized as a click so typing never moves the pointer.
    var pressKey: ((CGPoint) -> Bool)?
    /// The finger left the keyboard.
    var releaseKey: (() -> Void)?
    private var directPress: CGPoint?

    private let profile: DeviceProfile

    init?(profile: DeviceProfile,
          touchDisplay: CGDirectDisplayID,
          mainDisplay: CGDirectDisplayID,
          cursorReturn: CursorReturn) {
        guard let synthesizer = EventSynthesizer() else { return nil }
        self.synthesizer = synthesizer
        self.cursorReturn = cursorReturn
        self.profile = profile
        // Ranges come from the device's descriptor, so a panel with a different resolution
        // maps correctly without anyone editing a constant.
        self.mapper = CoordinateMapper(logicalMaxX: profile.logicalMaxX,
                                       logicalMaxY: profile.logicalMaxY,
                                       displayBounds: CGDisplayBounds(touchDisplay))
        self.palmFilter = PalmFilter(logicalMax: profile.logicalMax)
        self.returnTarget = Self.cursorReturnTarget(touchDisplay: touchDisplay, mainDisplay: mainDisplay)
    }

    /// Drives the clock-dependent half of the recognizer: long press on a still finger, the
    /// delayed two-finger right-click, and the backstop that releases a drag whose report
    /// stream died.
    func start() {
        heartbeat?.invalidate()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, self.recognizer.needsClock else { return }
            self.emit(self.recognizer.tick(at: Clock.now()))
        }
        // Common mode: in default mode the heartbeat stalls while a control in our own
        // keyboard panel is tracking — exactly when a held button most needs the backstop.
        RunLoop.main.add(timer, forMode: .common)
        heartbeat = timer
    }

    /// Re-reads geometry after a resolution change or a display being moved.
    func refreshGeometry(touchDisplay: CGDirectDisplayID, mainDisplay: CGDirectDisplayID) {
        mapper = CoordinateMapper(logicalMaxX: profile.logicalMaxX,
                                  logicalMaxY: profile.logicalMaxY,
                                  displayBounds: CGDisplayBounds(touchDisplay),
                                  calibration: mapper.calibration)
        returnTarget = Self.cursorReturnTarget(touchDisplay: touchDisplay, mainDisplay: mainDisplay)
        // Displays may have just become one: a return queued for the old layout must not fire.
        if returnTarget == nil { cursorReturn.cancelPendingReturn() }
    }

    var calibration: Calibration {
        get { mapper.calibration }
        set { mapper.calibration = newValue }
    }

    private var framesHandled = 0
    private var pointerMoves = 0
    private var hasSeenMultitouch = false
    private var scrollsEmitted = 0
    private var lastDiagnosticContactIDs: [UInt8] = []
    private var contactChangesLogged = 0
    private var pinchFramesLogged = 0

    /// True while the touchscreen is unusable — unplugged, asleep, or its monitor switched
    /// off. Reports keep arriving in that last case, because plenty of panels keep their
    /// USB side powered with the screen dark, and acting on them would drive the pointer to
    /// coordinates on a display nobody can see.
    private(set) var isSuspended = false

    func setSuspended(_ suspended: Bool) {
        guard suspended != isSuspended else { return }
        isSuspended = suspended
        // Whatever was under a finger when the screen went away has to be let go, or the
        // button stays logically held for the rest of the session.
        if suspended { releaseEverything() }
    }

    func handle(_ raw: TouchFrame) {
        guard !isSuspended else { return }

        let frame = palmFilter.reject(raw)
        let ids = frame.contacts.map(\.id).sorted()
        if ids != lastDiagnosticContactIDs {
            lastDiagnosticContactIDs = ids
            if contactChangesLogged < 120 {
                contactChangesLogged += 1
                log("Touch contacts: raw=\(raw.contacts.count) accepted=\(ids.count) ids=\(ids)")
            }
        }

        framesHandled += 1
        if framesHandled <= 12, let first = frame.contacts.first {
            let mapped = mapper.globalPoint(x: first.x, y: first.y)
            log("   → map (\(first.x),\(first.y)) ⇒ (\(Int(mapped.x)),\(Int(mapped.y)))")
        }

        if frame.contacts.count >= 2, !hasSeenMultitouch {
            hasSeenMultitouch = true
            log("Multitouch detected: \(frame.contacts.count) contacts.")
        }

        // A live touch means the user is not on the mouse — drop any queued cursor return.
        if !frame.contacts.isEmpty {
            cursorReturn.cancelPendingReturn()
        }

        let mapped = mapper.map(frame)

        // Keys must respond to the finger landing and leaving, full stop. Routing them
        // through the pointer recognizer meant a 0.4s press typed nothing (past the tap
        // window, short of the long press) and a 0.7s press fired a right click onto the
        // key — the single worst defect in the keyboard.
        if handleDirectTouch(mapped) { return }

        emit(recognizer.handle(mapped))
    }

    /// Returns true when the frame was consumed as a key press.
    private func handleDirectTouch(_ frame: MappedFrame) -> Bool {
        guard let region = directTouchRegion?() else {
            releaseDirectPress()
            return false
        }

        if directPress == nil {
            // Never hijack a gesture already in flight elsewhere on the screen.
            guard !recognizer.hasActiveGesture,
                  frame.contacts.count == 1,
                  let contact = frame.contacts.first,
                  region.contains(contact.point) else { return false }

            _ = pressKey?(contact.point)
            directPress = contact.point
            // Consumed either way: a finger inside the keyboard that landed between keys
            // must not fall through and click whatever sits behind the panel.
            return true
        }

        if let contact = frame.contacts.first(where: { region.contains($0.point) }) {
            directPress = contact.point
            return true
        }

        releaseDirectPress()
        return true
    }

    private func releaseDirectPress() {
        guard directPress != nil else { return }
        releaseKey?()
        directPress = nil
        // The keyboard swallows these frames, so the recognizer never reaches
        // `sessionEnded` and nothing else would ever arm the return. Without this, one tap
        // on a key stranded the cursor on the touchscreen for the rest of the session.
        armCursorReturn()
    }

    /// Closes out anything in flight. Called on quit, on unplug, and on sleep, so a pointer
    /// button is never left logically pressed for the rest of the login session.
    func releaseEverything() {
        // A key may still be under a finger; let it go on quit and on unplug.
        releaseDirectPress()
        emit(recognizer.forceRelease())
    }

    func stop() {
        heartbeat?.invalidate()
        heartbeat = nil
        releaseEverything()
    }

    private func emit(_ events: [GestureEvent]) {
        for event in events {
            if case .scroll(let dx, let dy, let at) = event {
                scrollsEmitted += 1
                if scrollsEmitted <= 6 {
                    log("   ↕︎ scroll \(Int(dx)),\(Int(dy)) at (\(Int(at.x)),\(Int(at.y)))")
                }
            }

            if case .pinch(let scale, _) = event, pinchFramesLogged < 30 {
                pinchFramesLogged += 1
                log(String(format: "Pinch frame ratio %.4f", Double(scale)))
            }
            synthesizer.apply(event)
            if case .sessionEnded = event {
                armCursorReturn()
            }
        }
    }
}
