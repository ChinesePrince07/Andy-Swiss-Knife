import CoreGraphics
import Foundation

struct ShotEvent: Equatable {
    let time: TimeInterval
    let point: CGPoint
}

/// Detects shuttle hits as sharp horizontal-velocity reversals (side-on view).
final class ShotDetector {
    let minPixelSpeed: Double
    let refractory: TimeInterval
    private(set) var shotCount = 0

    private var prev: TrajectorySample?
    private var prevVX: Double?       // last horizontal velocity (px/s)
    private var lastShotTime: TimeInterval = -.greatestFiniteMagnitude

    init(minPixelSpeed: Double = 300, refractory: TimeInterval = 0.2) {
        self.minPixelSpeed = minPixelSpeed
        self.refractory = refractory
    }

    func ingest(_ sample: TrajectorySample) -> ShotEvent? {
        defer { prev = sample }
        guard let p = prev else { return nil }
        let dt = sample.time - p.time
        guard dt > 0 else { return nil }
        let vx = (sample.point.x - p.point.x) / dt
        defer { prevVX = vx }
        guard let pvx = prevVX else { return nil }

        let reversed = (pvx > 0 && vx < 0) || (pvx < 0 && vx > 0)
        let fastEnough = abs(pvx) >= minPixelSpeed && abs(vx) >= minPixelSpeed
        let outsideRefractory = (sample.time - lastShotTime) >= refractory

        if reversed && fastEnough && outsideRefractory {
            lastShotTime = sample.time
            shotCount += 1
            return ShotEvent(time: sample.time, point: sample.point)
        }
        return nil
    }
}
