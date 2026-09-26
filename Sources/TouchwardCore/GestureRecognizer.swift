// Modified for Magic Mouse finger gestures, 2026-09-26.
import CoreGraphics
import Foundation

public struct GestureConfig: Sendable {
    public var tapMaxDuration: TimeInterval = 0.30
    public var longPressDuration: TimeInterval = 0.60
    public var moveThreshold: CGFloat = 10
    public var swipeThreshold: CGFloat = 60
    public var doubleTapInterval: TimeInterval = 0.35
    public var doubleTapDistance: CGFloat = 40
    /// A change-driven controller sends nothing while a finger rests, so this backstop
    /// releases a held button without claiming that the physical touch session ended.
    public var staleDragTimeout: TimeInterval = 2.0

    public init() {}
}

/// One finger scrolls; holding before moving drags. Two fingers navigate desktops or
/// double-tap Mission Control, and three or more pinch. Deltas are finger displacement;
/// the synthesizer owns polarity. Every drag and physical session ends exactly once.
public struct GestureRecognizer: Sendable {
    public var config: GestureConfig

    private enum TwoFingerMode {
        case undecided
        case horizontal(direction: CGFloat)
        case ignored
    }

    private struct TwoFinger {
        var startTime: TimeInterval
        var contacts: [MappedContact]
        var start: CGPoint
        var startSpread: CGFloat
        var canTap: Bool
        var needsReanchor = false
        var mode: TwoFingerMode = .undecided
    }

    private enum ThreeFingerMode {
        case undecided
        case pinch
        case ignored
    }

    private struct ThreeFinger {
        var contactIDs: [UInt8]
        var start: CGPoint
        var startSpread: CGFloat
        var lastSpread: CGFloat
        var mode: ThreeFingerMode = .undecided
    }

    private enum State {
        case idle
        case oneDown(id: UInt8, start: CGPoint, startTime: TimeInterval)
        case held(id: UInt8, start: CGPoint)
        case scrolling(id: UInt8, last: CGPoint)
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
                pendingTap = nil
                let contact = frame.contacts[0]
                state = .scrolling(id: contact.id, last: contact.point)
                return []
            }
            let held = frame.time - startTime >= config.longPressDuration
            if distance(point, start) > config.moveThreshold {
                pendingTap = nil
                if held {
                    state = .dragging(id: id, last: point)
                    return [.dragBegan(at: start), .dragMoved(to: point)]
                }
                state = .scrolling(id: id, last: point)
                return [.scroll(dx: point.x - start.x, dy: point.y - start.y, at: point)]
            }
            if held {
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

        case .scrolling(let id, let last):
            if count == 0 {
                state = .idle
                return [.sessionEnded]
            }
            if count >= 2 {
                beginMultiple(frame, canTap: false)
                return []
            }
            guard let point = point(of: id, in: frame) else {
                let contact = frame.contacts[0]
                state = .scrolling(id: contact.id, last: contact.point)
                return []
            }
            guard point != last else { return [] }
            state = .scrolling(id: id, last: point)
            return [.scroll(dx: point.x - last.x, dy: point.y - last.y, at: point)]

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
                                      start: centroid(frame), startSpread: spread(frame),
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
        if two.needsReanchor || ids != two.contacts.map(\.id).sorted() {
            two.canTap = false
            pendingTap = nil
            two.contacts = frame.contacts
            two.start = current
            two.startSpread = currentSpread
            two.needsReanchor = false
            state = .twoDown(two)
            return []
        }

        let dx = current.x - two.start.x
        let dy = current.y - two.start.y
        if case .undecided = two.mode {
            let travel = distance(current, two.start)
            let spreadChange = abs(currentSpread - two.startSpread)
            if travel >= config.moveThreshold, travel > spreadChange * 1.5 {
                if abs(dx) >= abs(dy) * 1.5 {
                    two.mode = .horizontal(direction: dx < 0 ? -1 : 1)
                } else if abs(dy) >= abs(dx) * 1.5 {
                    two.mode = .ignored
                }
            } else if spreadChange >= max(6, two.startSpread * 0.08), spreadChange > travel {
                two.mode = .ignored
            }
        }
        if case .horizontal(let direction) = two.mode,
           direction * dx >= config.swipeThreshold, abs(dx) >= abs(dy) * 1.5 {
            pendingTap = nil
            state = .consumed
            return [direction < 0 ? .swipeLeft : .swipeRight]
        }
        state = .twoDown(two)
        return []
    }

    private func threeFinger(_ frame: MappedFrame) -> ThreeFinger {
        let ids = frame.contacts.map(\.id).sorted()
        let currentSpread = spread(frame)
        return ThreeFinger(contactIDs: ids, start: centroid(frame),
                           startSpread: currentSpread, lastSpread: currentSpread)
    }

    private mutating func handleThree(_ frame: MappedFrame, previous: ThreeFinger) -> [GestureEvent] {
        let count = frame.contacts.count
        guard count > 0 else {
            state = .idle
            return [.sessionEnded]
        }
        var three = previous
        guard count >= 3 else {
            three.contactIDs = []
            state = .threeDown(three)
            return []
        }

        let ids = frame.contacts.map(\.id).sorted()
        let current = centroid(frame)
        let currentSpread = spread(frame)
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
                three.mode = .ignored
            } else if spreadChange >= max(6, three.startSpread * 0.08), spreadChange > travel {
                three.mode = .pinch
            }
        }

        switch three.mode {
        case .pinch:
            let scale = currentSpread / three.lastSpread
            three.lastSpread = currentSpread
            state = .threeDown(three)
            return scale == 1 ? [] : [.pinch(scale: scale, at: current)]
        case .undecided, .ignored:
            break
        }
        state = .threeDown(three)
        return []
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
