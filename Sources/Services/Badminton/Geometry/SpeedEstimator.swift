import CoreGraphics
import Foundation

struct ShotSpeed: Equatable {
    let metersPerSecond: Double
    var kmh: Double { metersPerSecond * 3.6 }
    var mph: Double { metersPerSecond * 2.2369362921 }
}

enum SpeedEstimator {
    /// A shuttlecock cannot physically exceed ~580 km/h (the record smash is
    /// ~565 km/h). Any instantaneous speed above this is a detection error — a
    /// residual teleport the gate let through, or a mis-calibrated scale — so it
    /// is discarded rather than reported. Guarantees the readout never shows an
    /// impossible value (offline study saw an ungated teleport imply 1696 km/h).
    static let maxPlausibleMetersPerSecond = 160.0   // 576 km/h

    /// Peak instantaneous speed over samples within [start, start+window],
    /// ignoring physically-impossible intervals (detection outliers).
    static func peakSpeed(samples: [TrajectorySample], from start: TimeInterval,
                          window: TimeInterval, scale: ReferenceScale,
                          maxPlausibleMS: Double = maxPlausibleMetersPerSecond) -> ShotSpeed? {
        let win = samples.filter { $0.time >= start && $0.time <= start + window }
        guard win.count >= 2 else { return nil }
        var peak = 0.0
        for i in 1..<win.count {
            let dt = win[i].time - win[i - 1].time
            guard dt > 0 else { continue }
            let speed = scale.meters(from: win[i - 1].point, to: win[i].point) / dt
            if speed > maxPlausibleMS { continue }   // physically impossible -> detection error
            peak = max(peak, speed)
        }
        guard peak > 0 else { return nil }
        return ShotSpeed(metersPerSecond: peak)
    }
}
