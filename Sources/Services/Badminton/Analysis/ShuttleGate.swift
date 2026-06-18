import CoreGraphics
import Foundation

/// Rejects implausible shuttle "teleports" — spurious detections that jump far
/// from the established track in a single frame. These are the noise spikes that
/// make the trail bounce around. After `maxMisses` consecutive rejections it
/// re-acquires (the track may be genuinely stale), so it can't get stuck.
struct ShuttleGate {
    let maxFractionPerFrame: Double   // max jump as a fraction of the frame's long edge, per 1/30 s
    let maxMisses: Int
    private let refFrameRate = 30.0
    private var last: (point: CGPoint, time: TimeInterval)?
    private var misses = 0

    init(maxFractionPerFrame: Double = 0.3, maxMisses: Int = 5) {
        self.maxFractionPerFrame = maxFractionPerFrame
        self.maxMisses = maxMisses
    }

    mutating func accept(_ point: CGPoint, time: TimeInterval, frameSize: CGSize) -> Bool {
        guard let l = last else { last = (point, time); misses = 0; return true }
        let dt = max(time - l.time, 1.0 / 120.0)
        let dist = hypot(point.x - l.point.x, point.y - l.point.y)
        let maxJump = Double(max(frameSize.width, frameSize.height)) * maxFractionPerFrame * (dt * refFrameRate)
        if dist > maxJump && misses < maxMisses {
            misses += 1
            return false
        }
        last = (point, time)
        misses = 0
        return true
    }
}
