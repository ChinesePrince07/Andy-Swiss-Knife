import Observation
import CoreGraphics
import CoreVideo
import Foundation

/// Sendable snapshot of one processed frame, handed from the camera's serial
/// delivery queue to the main actor for publishing.
struct FrameResult: Sendable {
    let frameSize: CGSize
    let trail: [CGPoint]
    let latestPoint: CGPoint?
    let fps: Double
    let shotCount: Int
    let shot: ShotEvent?
    /// Trajectory samples captured at the moment of a shot (for speed in P2);
    /// empty unless `shot != nil`.
    let samplesAtShot: [TrajectorySample]
}

/// Owns the per-frame analysis state (detector, trajectory, shot + fps counters).
/// Created and used ONLY on the camera's serial delivery queue — never touched
/// from the main actor — so its mutable state needs no locking and crosses no
/// isolation boundary. It hands back a Sendable `FrameResult`.
final class FrameProcessor {
    private let detector: ShuttleDetector
    private let trajectory = ShuttleTrajectory(trailWindow: 1.0, maxGap: 0.3)
    private let shots = ShotDetector()
    private let fpsCounter = FPSCounter()

    init(detector: ShuttleDetector) { self.detector = detector }

    func process(_ buffer: CVPixelBuffer, time: TimeInterval) -> FrameResult {
        let size = CGSize(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
        fpsCounter.tick(at: time)
        guard let obs = detector.detect(pixelBuffer: buffer, time: time) else {
            return FrameResult(frameSize: size, trail: trajectory.trail, latestPoint: nil,
                               fps: fpsCounter.fps, shotCount: shots.shotCount, shot: nil, samplesAtShot: [])
        }
        trajectory.add(obs)
        let shot = shots.ingest(TrajectorySample(point: obs.point, time: obs.time))
        return FrameResult(frameSize: size, trail: trajectory.trail, latestPoint: obs.point,
                           fps: fpsCounter.fps, shotCount: shots.shotCount, shot: shot,
                           samplesAtShot: shot == nil ? [] : trajectory.samples)
    }
}

@Observable
@MainActor
final class BadmintonEngine {
    // Published UI state
    var trail: [CGPoint] = []
    var latestPoint: CGPoint?
    var fps: Double = 0
    var shotCount: Int = 0
    var isRunning = false
    var frameSize: CGSize = .zero
    var cameraDenied = false
    var lastSpeed: ShotSpeed?
    var maxSpeed: ShotSpeed?
    var settings: BadmintonSettings = .shared

    let captureFPS: Int
    let camera = CameraSession()
    private let processor: FrameProcessor

    init(detector: ShuttleDetector = MotionShuttleDetector(), captureFPS: Int = 60) {
        self.captureFPS = captureFPS
        self.processor = FrameProcessor(detector: detector)
        let processor = self.processor
        camera.onFrame = { [weak self] buffer, time in
            // Runs on the camera's serial delivery queue: do the heavy detection
            // here, then hop only the Sendable result to the main actor.
            let result = processor.process(buffer, time: time)
            Task { @MainActor in self?.apply(result) }
        }
    }

    func start() async {
        guard !isRunning else { return }
        let ok = await camera.configure(fps: captureFPS)
        guard ok else { cameraDenied = true; return }
        camera.start()
        isRunning = true
    }

    func stop() {
        camera.stop()
        isRunning = false
    }

    /// Publishes a processed frame's result on the main actor, and — once a
    /// reference scale is calibrated — computes the peak speed of each shot.
    func apply(_ result: FrameResult) {
        frameSize = result.frameSize
        fps = result.fps
        trail = result.trail
        latestPoint = result.latestPoint
        shotCount = result.shotCount
        if let shot = result.shot, let scale = settings.scale,
           let speed = SpeedEstimator.peakSpeed(
               samples: result.samplesAtShot, from: shot.time, window: 0.08, scale: scale) {
            lastSpeed = speed
            if speed.metersPerSecond > (maxSpeed?.metersPerSecond ?? 0) { maxSpeed = speed }
        }
    }
}
