import CoreGraphics
import Foundation

struct ShotEvent: Equatable {
    let time: TimeInterval
    let point: CGPoint
}

/// Detects shuttle hits as a SUSTAINED horizontal-direction reversal: the shuttle
/// must travel consistently one way for at least `minRun` fast frames before a
/// stroke in that direction counts.
///
/// Requiring a sustained run — rather than a single-frame velocity flip — rejects
/// frame-difference noise. Noise detections land at random positions, so they flip
/// horizontal direction almost every frame and never build a run of `minRun`
/// consistent fast frames. A real shuttle, by contrast, travels in one direction
/// across the court for many frames between hits.
final class ShotDetector {
    let minPixelSpeed: Double
    let minRun: Int
    let refractory: TimeInterval

    private(set) var shotCount = 0

    private var prev: TrajectorySample?
    private var runDir = 0          // -1 / 0 / +1 : current sustained direction
    private var runLength = 0       // consecutive fast frames in `runDir`
    private var lastStrokeDir = 0   // direction of the last counted stroke
    private var lastShotTime: TimeInterval = -.greatestFiniteMagnitude

    init(minPixelSpeed: Double = 350, minRun: Int = 3, refractory: TimeInterval = 0.12) {
        self.minPixelSpeed = minPixelSpeed
        self.minRun = minRun
        self.refractory = refractory
    }

    func ingest(_ sample: TrajectorySample) -> ShotEvent? {
        defer { prev = sample }
        guard let p = prev else { return nil }
        let dt = sample.time - p.time
        guard dt > 0 else { return nil }

        let vx = (sample.point.x - p.point.x) / dt
        let dir = vx >= minPixelSpeed ? 1 : (vx <= -minPixelSpeed ? -1 : 0)
        // Ignore slow / ambiguous frames (e.g. near the apex): don't break the run.
        guard dir != 0 else { return nil }

        if dir == runDir {
            runLength += 1
        } else {
            runDir = dir
            runLength = 1
        }

        // A stroke qualifies the instant its run first reaches `minRun`, in a
        // direction different from the previous counted stroke.
        guard runLength == minRun, dir != lastStrokeDir else { return nil }
        lastStrokeDir = dir
        guard sample.time - lastShotTime >= refractory else { return nil }
        lastShotTime = sample.time
        shotCount += 1
        return ShotEvent(time: sample.time, point: sample.point)
    }
}
