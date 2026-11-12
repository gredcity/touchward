// Modified for CreateBoard scroll and desktop gestures, 2026-10-23.
import CoreGraphics
import Foundation

public struct GestureConfig: Sendable {
    public var tapMaxDuration: TimeInterval = 0.30
    public var longPressDuration: TimeInterval = 0.60
    public var moveThreshold: CGFloat = 10
    public var swipeThreshold: CGFloat = 60
    public var doubleTapInterval: TimeInterval = 0.35
    public var doubleTapDistance: CGFloat = 40
    /// Mean radius in display points; closer contacts make ratios amplify tiny jitter.
    public var minimumPinchSpread: CGFloat = 12
    public var pinchNoiseThreshold: CGFloat = 4
    public var pinchReversalThreshold: CGFloat = 12
    /// A change-driven controller sends nothing while a finger rests, so this backstop
    /// releases a held button without claiming that the physical touch session ended.
    public var staleDragTimeout: TimeInterval = 2.0

    public init() {}
}

/// Two fingers scroll, pinch, or double-tap Mission Control; exactly three swipe desktops.
/// One finger is a mouse: tap clicks, hold-and-lift right-clicks, moving drags (so title
/// bars move windows). Scrolling is two fingers only. Three or more can also pinch.
/// Deltas are finger displacement;
/// the synthesizer owns polarity. Every drag and physical session ends exactly once.
public struct GestureRecognizer: Sendable {
    public var config: GestureConfig

    private enum TwoFingerMode {
        case undecided
        case scrolling
        case pinch
        case ignored
    }

    private struct TwoFinger {
        var startTime: TimeInterval
        var contacts: [MappedContact]
        var start: CGPoint
        var last: CGPoint
        var startSpread: CGFloat
        var lastSpread: CGFloat
        var canTap: Bool
        var needsReanchor = false
        var mode: TwoFingerMode = .undecided
        var pinchDirection: CGFloat = 0
    }

    private enum ThreeFingerMode {
        case undecided
        case horizontal(direction: CGFloat)
        case pinch
        case ignored
    }

    private struct ThreeFinger {
        var contactIDs: [UInt8]
        var canSwipe: Bool
        var start: CGPoint
        var startSpread: CGFloat
        var lastSpread: CGFloat
        var mode: ThreeFingerMode = .undecided
        var pinchDirection: CGFloat = 0
    }

    private enum State {
        case idle
        case oneDown(id: UInt8, start: CGPoint, startTime: TimeInterval)
        case held(id: UInt8, start: CGPoint)
        case dragging(id: UInt8, last: CGPoint)
        case twoDown(TwoFinger)
        case threeDown(ThreeFinger)
        case consumed
    }

    private var state: State = .idle
    private var lastFrameTime: TimeInterval = 0
    private var pendingTap: (time: TimeInterval, point: CGPoint)?

    public init(config: GestureConfig = GestureConfig()) {
        self.config = config
    }

    /// Gates the production heartbeat for held touches and the stale-drag backstop.
    public var hasActiveGesture: Bool {
        if case .idle = state { return false }
        return true
    }

    public mutating func handle(_ frame: MappedFrame) -> [GestureEvent] {
        let ordered = frame.time >= lastFrameTime
        if !ordered { pendingTap = nil }
        lastFrameTime = max(lastFrameTime, frame.time)
        let count = frame.contacts.count

        switch state {
        case .idle:
            switch count {
            case 0:
                break
            case 1:
                let contact = frame.contacts[0]
                state = .oneDown(id: contact.id, start: contact.point, startTime: frame.time)
            default:
                beginMultiple(frame, canTap: ordered)
            }
            return []

        case .oneDown(let id, let start, let startTime):
            if count == 0 {
                state = .idle
                pendingTap = nil
                if frame.time - startTime >= config.longPressDuration {
                    return [.rightClick(at: start), .sessionEnded]
                }
                return isWithinTapWindow(frame.time, since: startTime)
                    ? [.leftClick(at: start), .sessionEnded] : [.sessionEnded]
            }
            if count >= 2 {
                beginMultiple(frame, canTap: ordered && frame.time - startTime < config.longPressDuration)
                return []
            }
            guard let point = point(of: id, in: frame) else {
                // Replaced contact: its position is unrelated to `start`, so pressing there
                // would drag from the wrong place. Wait for the lift, like `.held` does.
                pendingTap = nil
                state = .consumed
                return []
            }
            if distance(point, start) > config.moveThreshold {
                pendingTap = nil
                state = .dragging(id: id, last: point)
                return [.dragBegan(at: start), .dragMoved(to: point)]
            }
            if frame.time - startTime >= config.longPressDuration {
                pendingTap = nil
                state = .held(id: id, start: start)
            }
            return []

        case .held(let id, let start):
            if count == 0 {
                state = .idle
                return [.rightClick(at: start), .sessionEnded]
            }
            if count >= 2 {
                beginMultiple(frame, canTap: false)
                return []
            }
            guard let point = point(of: id, in: frame) else {
                state = .consumed
                return []
            }
            guard distance(point, start) > config.moveThreshold else { return [] }
            state = .dragging(id: id, last: point)
            return [.dragBegan(at: start), .dragMoved(to: point)]

        case .dragging(let id, let last):
            if count == 0 {
                state = .idle
                return [.dragEnded(at: last), .sessionEnded]
            }
            if count >= 2 {
                beginMultiple(frame, canTap: false)
                return [.dragEnded(at: last)]
            }
            guard let point = point(of: id, in: frame) else {
                state = .consumed
                return [.dragEnded(at: last)]
            }
            guard point != last else { return [] }
            state = .dragging(id: id, last: point)
            return [.dragMoved(to: point)]

        case .twoDown(var two):
            if !ordered { two.canTap = false }
            return handleTwo(frame, previous: two)

        case .threeDown(let three):
            return handleThree(frame, previous: three)

        case .consumed:
            guard count == 0 else { return [] }
            state = .idle
            return [.sessionEnded]
        }
    }

    public mutating func tick(at time: TimeInterval) -> [GestureEvent] {
        switch state {
        case .oneDown(let id, let start, let startTime):
            guard time - startTime >= config.longPressDuration else { return [] }
            pendingTap = nil
            state = .held(id: id, start: start)
            return []
        case .dragging(_, let last):
            guard time - lastFrameTime > config.staleDragTimeout else { return [] }
            state = .consumed
            return [.dragEnded(at: last)]
        default:
            return []
        }
    }

    public mutating func forceRelease() -> [GestureEvent] {
        pendingTap = nil
        switch state {
        case .idle:
            return []
        case .dragging(_, let last):
            state = .idle
            return [.dragEnded(at: last), .sessionEnded]
        default:
            state = .idle
            return [.sessionEnded]
        }
    }

    private mutating func beginMultiple(_ frame: MappedFrame, canTap: Bool) {
        if frame.contacts.count >= 3 {
            pendingTap = nil
            state = .threeDown(threeFinger(frame))
        } else {
            let unique = Set(frame.contacts.map(\.id)).count == 2
            if !canTap || !unique { pendingTap = nil }
            state = .twoDown(TwoFinger(startTime: frame.time, contacts: frame.contacts,
                                      start: centroid(frame), last: centroid(frame),
                                      startSpread: spread(frame), lastSpread: spread(frame),
                                      canTap: canTap && unique,
                                      mode: unique ? .undecided : .ignored))
        }
    }

    private mutating func handleTwo(_ frame: MappedFrame, previous: TwoFinger) -> [GestureEvent] {
        var two = previous
        let count = frame.contacts.count
        if count == 0 {
            state = .idle
            return finishTwoFinger(two, at: frame.time)
        }
        if case .pinch = two.mode,
           count != 2 || frame.contacts.map(\.id).sorted() != two.contacts.map(\.id).sorted()
            || spread(frame) < config.minimumPinchSpread {
            // A lift, merged tips, or changed contact set ends zoom immediately. Never
            // resume it from trailing/rediscovered contacts before a full physical lift.
            state = .consumed
            return []
        }
        if count >= 3 {
            beginMultiple(frame, canTap: false)
            return []
        }
        if frame.contacts.contains(where: { contact in
            guard let anchor = two.contacts.first(where: { $0.id == contact.id }) else { return true }
            return distance(contact.point, anchor.point) > config.moveThreshold
        }) {
            two.canTap = false
            pendingTap = nil
        }
        if count == 1 {
            two.needsReanchor = true
            state = .twoDown(two)
            return []
        }

        let ids = frame.contacts.map(\.id).sorted()
        if Set(ids).count != 2 {
            two.canTap = false
            two.mode = .ignored
            pendingTap = nil
        }
        let current = centroid(frame)
        let currentSpread = spread(frame)
        if two.needsReanchor || ids != two.contacts.map(\.id).sorted()
            || two.startSpread <= 0 || currentSpread <= 0 {
            two.canTap = false
            pendingTap = nil
            two.contacts = frame.contacts
            two.start = current
            two.last = current
            two.startSpread = currentSpread
            two.lastSpread = currentSpread
            two.needsReanchor = false
            state = .twoDown(two)
            return []
        }

        if case .undecided = two.mode {
            let travel = distance(current, two.start)
            let spreadChange = abs(currentSpread - two.startSpread)
            if travel >= config.moveThreshold, travel > spreadChange * 1.5 {
                two.canTap = false
                pendingTap = nil
                two.mode = .scrolling
            } else if spreadChange >= max(6, two.startSpread * 0.08), spreadChange >= travel {
                two.canTap = false
                pendingTap = nil
                if two.startSpread >= config.minimumPinchSpread,
                   currentSpread >= config.minimumPinchSpread {
                    two.mode = .pinch
                } else {
                    two.start = current
                    two.last = current
                    two.startSpread = currentSpread
                    two.lastSpread = currentSpread
                }
            }
        }
        if case .scrolling = two.mode {
            let dx = current.x - two.last.x
            let dy = current.y - two.last.y
            two.last = current
            state = .twoDown(two)
            return dx == 0 && dy == 0 ? [] : [.scroll(dx: dx, dy: dy, at: current)]
        }
        if case .pinch = two.mode {
            let scale = stabilizedPinchScale(currentSpread, last: &two.lastSpread,
                                             direction: &two.pinchDirection)
            state = .twoDown(two)
            return scale.map { [.pinch(scale: $0, at: current)] } ?? []
        }
        state = .twoDown(two)
        return []
    }

    private func threeFinger(_ frame: MappedFrame) -> ThreeFinger {
        let ids = frame.contacts.map(\.id).sorted()
        let currentSpread = spread(frame)
        return ThreeFinger(contactIDs: ids, canSwipe: ids.count == 3 && Set(ids).count == 3,
                           start: centroid(frame),
                           startSpread: currentSpread, lastSpread: currentSpread)
    }

    private mutating func handleThree(_ frame: MappedFrame, previous: ThreeFinger) -> [GestureEvent] {
        let count = frame.contacts.count
        guard count > 0 else {
            state = .idle
            return [.sessionEnded]
        }
        var three = previous
        if case .pinch = three.mode,
           frame.contacts.map(\.id).sorted() != three.contactIDs
            || spread(frame) < config.minimumPinchSpread {
            state = .consumed
            return []
        }
        guard count >= 3 else {
            three.contactIDs = []
            state = .threeDown(three)
            return []
        }

        let ids = frame.contacts.map(\.id).sorted()
        let current = centroid(frame)
        let currentSpread = spread(frame)
        // A fourth contact or duplicate IDs cannot qualify as a desktop swipe,
        // including after it lifts again. Committed pinches already stop on contact change.
        if count != 3 || Set(ids).count != 3 {
            three.canSwipe = false
            if case .horizontal = three.mode { three.mode = .ignored }
        }
        if Set(ids).count != count { three.mode = .ignored }
        guard ids == three.contactIDs, three.startSpread > 0, currentSpread > 0 else {
            three.contactIDs = ids
            three.start = current
            three.startSpread = currentSpread
            three.lastSpread = currentSpread
            state = .threeDown(three)
            return []
        }

        if case .undecided = three.mode {
            let travel = distance(current, three.start)
            let spreadChange = abs(currentSpread - three.startSpread)
            if travel >= config.moveThreshold, travel > spreadChange * 1.5 {
                let dx = current.x - three.start.x
                let dy = current.y - three.start.y
                if three.canSwipe, abs(dx) >= abs(dy) * 1.5 {
                    three.mode = .horizontal(direction: dx < 0 ? -1 : 1)
                } else if !three.canSwipe || abs(dy) >= abs(dx) * 1.5 {
                    three.mode = .ignored
                }
            } else if spreadChange >= max(6, three.startSpread * 0.08), spreadChange > travel {
                if three.startSpread >= config.minimumPinchSpread,
                   currentSpread >= config.minimumPinchSpread {
                    three.mode = .pinch
                } else {
                    three.start = current
                    three.startSpread = currentSpread
                    three.lastSpread = currentSpread
                }
            }
        }

        switch three.mode {
        case .horizontal(let direction):
            let dx = current.x - three.start.x
            let dy = current.y - three.start.y
            if direction * dx >= config.swipeThreshold, abs(dx) >= abs(dy) * 1.5 {
                state = .consumed
                return [direction < 0 ? .swipeLeft : .swipeRight]
            }
        case .pinch:
            let scale = stabilizedPinchScale(currentSpread, last: &three.lastSpread,
                                             direction: &three.pinchDirection)
            state = .threeDown(three)
            return scale.map { [.pinch(scale: $0, at: current)] } ?? []
        case .undecided, .ignored:
            break
        }
        state = .threeDown(three)
        return []
    }

    /// Keep the last accepted spread as the anchor, so small movements accumulate but
    /// jitter cannot repeatedly alternate zoom directions around the same hand position.
    private func stabilizedPinchScale(_ current: CGFloat, last: inout CGFloat,
                                      direction: inout CGFloat) -> CGFloat? {
        guard current.isFinite, last.isFinite, last > 0 else { return nil }
        let delta = current - last
        guard delta != 0 else { return nil }
        let nextDirection: CGFloat = delta > 0 ? 1 : -1
        let reversing = direction != 0 && direction != nextDirection
        let threshold = reversing
            ? max(config.pinchReversalThreshold, last * 0.15)
            : max(config.pinchNoiseThreshold, last * 0.02)
        guard abs(delta) >= threshold else { return nil }
        let scale = current / last
        last = current
        direction = nextDirection
        return scale
    }

    /// Mean distance from the centroid: how open the hand is, in points. Comparing this
    /// frame to frame is what separates a zoom from a hand sliding across the glass.
    private func spread(_ frame: MappedFrame) -> CGFloat {
        guard frame.contacts.count > 1 else { return 0 }
        let centre = centroid(frame)
        let total = frame.contacts.reduce(CGFloat.zero) { $0 + distance($1.point, centre) }
        return total / CGFloat(frame.contacts.count)
    }

    private mutating func finishTwoFinger(_ two: TwoFinger, at time: TimeInterval) -> [GestureEvent] {
        guard two.canTap, isWithinTapWindow(time, since: two.startTime) else {
            pendingTap = nil
            return [.sessionEnded]
        }
        if let previous = pendingTap,
           two.startTime >= previous.time,
           two.startTime - previous.time <= config.doubleTapInterval,
           distance(two.start, previous.point) <= config.doubleTapDistance {
            pendingTap = nil
            return [.missionControl, .sessionEnded]
        }
        pendingTap = (time, two.start)
        return [.sessionEnded]
    }

    /// A negative interval means the reports arrived out of order or the clock moved.
    /// Treating that as "elapsed 0" would classify a long hold as an instant tap and fire
    /// a click the user never asked for, so an unusable measurement is never a tap.
    private func isWithinTapWindow(_ time: TimeInterval, since start: TimeInterval) -> Bool {
        let interval = time - start
        return interval >= 0 && interval <= config.tapMaxDuration
    }

    private func point(of id: UInt8, in frame: MappedFrame) -> CGPoint? {
        frame.contacts.first { $0.id == id }?.point
    }

    private func centroid(_ frame: MappedFrame) -> CGPoint {
        guard !frame.contacts.isEmpty else { return .zero }
        let sum = frame.contacts.reduce(CGPoint.zero) {
            CGPoint(x: $0.x + $1.point.x, y: $0.y + $1.point.y)
        }
        let n = CGFloat(frame.contacts.count)
        return CGPoint(x: sum.x / n, y: sum.y / n)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x, dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
