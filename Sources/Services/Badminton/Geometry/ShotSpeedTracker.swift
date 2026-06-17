import CoreGraphics
import Foundation

/// Measures the peak OUTGOING speed of a shot by accumulating samples that
/// arrive AFTER the hit.
///
/// On the exact frame a shot (velocity reversal) is detected, no post-hit
/// samples exist yet, so a forward speed window is empty. Naively computing
/// speed at that instant always yields nil. This tracker remembers the pending
/// shot and recomputes the peak as later frames arrive, capturing the outgoing
/// smash (fastest just after racket contact). The window auto-closes once
/// `window` seconds have elapsed past the shot.
struct ShotSpeedTracker {
    let window: TimeInterval
    private var pendingShotTime: TimeInterval?
    private(set) var lastSpeed: ShotSpeed?
    private(set) var maxSpeed: ShotSpeed?

    init(window: TimeInterval = 0.08) { self.window = window }

    /// Call once per processed frame.
    /// - Parameters:
    ///   - shotTime: non-nil only on the frame a shot is detected.
    ///   - now: this frame's timestamp.
    ///   - samples: recent trajectory samples (must span the post-shot window).
    ///   - scale: the calibrated scale, or nil if not yet calibrated.
    mutating func update(shotTime: TimeInterval?, now: TimeInterval,
                         samples: [TrajectorySample], scale: ReferenceScale?) {
        if let shotTime { pendingShotTime = shotTime }
        guard let pending = pendingShotTime else { return }
        if let scale,
           let speed = SpeedEstimator.peakSpeed(samples: samples, from: pending, window: window, scale: scale) {
            lastSpeed = speed
            if speed.metersPerSecond > (maxSpeed?.metersPerSecond ?? 0) { maxSpeed = speed }
        }
        // Close the window once it has fully elapsed (independent of scale, so a
        // stale pending shot never lingers).
        if now >= pending + window { pendingShotTime = nil }
    }

    mutating func resetSpeeds() {
        lastSpeed = nil
        maxSpeed = nil
        pendingShotTime = nil
    }
}
