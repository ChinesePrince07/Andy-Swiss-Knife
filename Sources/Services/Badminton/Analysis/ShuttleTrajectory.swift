import CoreGraphics
import Foundation

struct TrajectorySample: Equatable {
    let point: CGPoint
    let time: TimeInterval
}

/// Accumulates recent shuttle observations, prunes anything older than
/// `trailWindow`, and exposes the trail + instantaneous velocity.
final class ShuttleTrajectory {
    let trailWindow: TimeInterval
    let maxGap: TimeInterval
    private(set) var samples: [TrajectorySample] = []

    init(trailWindow: TimeInterval = 1.0, maxGap: TimeInterval = 0.3) {
        self.trailWindow = trailWindow
        self.maxGap = maxGap
    }

    func add(_ obs: ShuttleObservation) {
        samples.append(TrajectorySample(point: obs.point, time: obs.time))
        let cutoff = obs.time - trailWindow
        samples.removeAll { $0.time < cutoff }
    }

    var trail: [CGPoint] { samples.map(\.point) }

    /// Pixels/second from the last two samples, or nil if too few or gap too large.
    func velocity() -> CGVector? {
        guard samples.count >= 2 else { return nil }
        let a = samples[samples.count - 2]
        let b = samples[samples.count - 1]
        let dt = b.time - a.time
        guard dt > 0, dt <= maxGap else { return nil }
        return CGVector(dx: (b.point.x - a.point.x) / dt, dy: (b.point.y - a.point.y) / dt)
    }
}
