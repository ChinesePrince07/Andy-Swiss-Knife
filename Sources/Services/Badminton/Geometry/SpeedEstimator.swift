import CoreGraphics
import Foundation

struct ShotSpeed: Equatable {
    let metersPerSecond: Double
    var kmh: Double { metersPerSecond * 3.6 }
    var mph: Double { metersPerSecond * 2.2369362921 }
}

enum SpeedEstimator {
    /// Peak instantaneous speed over samples within [start, start+window].
    static func peakSpeed(samples: [TrajectorySample], from start: TimeInterval,
                          window: TimeInterval, scale: ReferenceScale) -> ShotSpeed? {
        let win = samples.filter { $0.time >= start && $0.time <= start + window }
        guard win.count >= 2 else { return nil }
        var peak = 0.0
        for i in 1..<win.count {
            let dt = win[i].time - win[i - 1].time
            guard dt > 0 else { continue }
            let speed = scale.meters(from: win[i - 1].point, to: win[i].point) / dt
            peak = max(peak, speed)
        }
        guard peak > 0 else { return nil }
        return ShotSpeed(metersPerSecond: peak)
    }
}
