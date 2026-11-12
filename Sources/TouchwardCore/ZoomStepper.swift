import CoreGraphics
import Foundation

/// Converts incremental pinch ratios into the focused app's discrete zoom shortcuts.
public struct ZoomStepper: Sendable {
    private let threshold = CoreGraphics.log(CGFloat(1.10))
    private var residual: CGFloat = 0
    private var lastShortcutTime: TimeInterval?
    private let minimumInterval: TimeInterval = 0.12

    public init() {}

    public mutating func consume(scale: CGFloat, at time: TimeInterval) -> Int {
        guard scale > 0, scale != 1, scale.isFinite, time.isFinite else { return 0 }
        if let lastShortcutTime, time < lastShortcutTime { return 0 }
        residual += CoreGraphics.log(scale)
        guard abs(residual) >= threshold else { return 0 }
        let direction = residual > 0 ? 1 : -1
        // Discard excess whole steps, including those during the cooldown. There is no
        // timer or pending command queue to keep zooming after the hand stops or lifts.
        residual = residual.truncatingRemainder(dividingBy: threshold)
        if let lastShortcutTime, time - lastShortcutTime < minimumInterval { return 0 }
        lastShortcutTime = time
        return direction
    }

    public mutating func reset() {
        residual = 0
        lastShortcutTime = nil
    }
}
