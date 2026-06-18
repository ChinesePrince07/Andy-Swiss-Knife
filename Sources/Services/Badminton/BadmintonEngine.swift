import Observation
import CoreGraphics
import CoreVideo
import Foundation
import os

/// Sendable snapshot of one processed frame, handed from the camera's serial
/// delivery queue to the main actor for publishing.
struct FrameResult: Sendable {
    let time: TimeInterval          // this frame's timestamp (always present)
    let frameSize: CGSize
    let trail: [CGPoint]
    let latestPoint: CGPoint?
    let fps: Double
    let shotCount: Int
    let shot: ShotEvent?            // non-nil only on the frame a shot is detected
    let recentSamples: [TrajectorySample]   // trajectory samples (≤ trail window), always
    let poses: [PlayerPose]         // most-recent player poses (refreshed every Nth frame)
}

/// Owns the per-frame analysis state (detector, trajectory, shot + fps counters).
/// Created on the main actor but used ONLY on the camera's serial delivery queue,
/// so its mutable state needs no locking. `@unchecked Sendable` lets it be
/// captured by the `@Sendable` `onFrame` closure; the single-queue confinement is
/// what makes that assertion sound.
final class FrameProcessor: @unchecked Sendable {
    private let detector: ShuttleDetector
    private let poseDetector: PoseDetector?
    private let poseEvery: Int
    private let trajectory = ShuttleTrajectory(trailWindow: 1.0, maxGap: 0.3)
    private let shots = ShotDetector()
    private let fpsCounter = FPSCounter()
    private var frameCounter = 0
    private var lastPoses: [PlayerPose] = []
    private var gate = ShuttleGate()

    init(detector: ShuttleDetector, poseDetector: PoseDetector? = nil, poseEvery: Int = 5) {
        self.detector = detector
        self.poseDetector = poseDetector
        self.poseEvery = max(1, poseEvery)
    }

    func process(_ buffer: CVPixelBuffer, time: TimeInterval) -> FrameResult {
        let size = CGSize(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
        fpsCounter.tick(at: time)

        // Players move slowly relative to the shuttle, so run the heavier pose
        // model only every Nth frame; the last poses persist between updates.
        frameCounter += 1
        if let poseDetector, frameCounter % poseEvery == 0 {
            lastPoses = poseDetector.detect(pixelBuffer: buffer)
        }

        // Reject teleporting outliers (noise) so the trail follows continuous motion.
        var accepted: ShuttleObservation?
        if let detected = detector.detect(pixelBuffer: buffer, time: time),
           gate.accept(detected.point, time: time, frameSize: size) {
            accepted = detected
        }
        guard let obs = accepted else {
            return FrameResult(time: time, frameSize: size, trail: trajectory.trail, latestPoint: nil,
                               fps: fpsCounter.fps, shotCount: shots.shotCount, shot: nil,
                               recentSamples: trajectory.samples, poses: lastPoses)
        }
        trajectory.add(obs)
        let shot = shots.ingest(TrajectorySample(point: obs.point, time: obs.time))
        return FrameResult(time: time, frameSize: size, trail: trajectory.trail, latestPoint: obs.point,
                           fps: fpsCounter.fps, shotCount: shots.shotCount, shot: shot,
                           recentSamples: trajectory.samples, poses: lastPoses)
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
    var players: [LabeledPose] = []
    var scoreP1 = 0
    var scoreP2 = 0
    var lastShot: ShotMarker?
    var settings: BadmintonSettings = .shared

    let captureFPS: Int
    let camera = CameraSession()
    // The processor (incl. its detector) is swapped when the detector mode
    // changes; the lock lets the @Sendable camera callback read the current one
    // safely from the delivery queue while start() rebuilds it on the main actor.
    private let processorBox: OSAllocatedUnfairLock<FrameProcessor>
    private var speedTracker = ShotSpeedTracker(window: 0.08)
    private let scorer = AutoScorer()
    private var shotSeq = 0

    init(detector: ShuttleDetector = MotionShuttleDetector(), captureFPS: Int = 60) {
        self.captureFPS = captureFPS
        self.processorBox = OSAllocatedUnfairLock(initialState: FrameProcessor(detector: detector))
        let box = processorBox
        camera.onFrame = { [weak self] buffer, time in
            // Runs on the camera's serial delivery queue: do the heavy detection
            // here, then hop only the Sendable result to the main actor.
            let result = box.withLockUnchecked { $0.process(buffer, time: time) }
            Task { @MainActor in self?.apply(result) }
        }
    }

    func start() async {
        // Skip if already running, or if the user already denied access (avoids
        // re-running configure on every foreground transition once denied).
        guard !isRunning, !cameraDenied else { return }
        rebuildProcessor()
        let ok = await camera.configure(fps: captureFPS)
        guard ok else { cameraDenied = true; return }
        camera.start()
        isRunning = true
    }

    func stop() {
        camera.stop()
        isRunning = false
    }

    /// Build the processor: TrackNetV3 (bundled Core ML) for the shuttle; if the
    /// model can't load, fall back to the classical detector so it still functions.
    private func rebuildProcessor() {
        let detector: ShuttleDetector = TrackNetShuttleDetector() ?? MotionShuttleDetector()
        let pose = YOLOPoseDetector()   // nil if the model can't load -> no skeletons
        processorBox.withLockUnchecked { $0 = FrameProcessor(detector: detector, poseDetector: pose) }
    }

    /// Clears the measured speeds (e.g. on recalibration, since prior values were
    /// computed under the old scale).
    func resetSpeeds() {
        speedTracker.resetSpeeds()
        lastSpeed = nil
        maxSpeed = nil
    }

    /// Publishes a processed frame's result on the main actor, and — once a
    /// reference scale is calibrated — measures the peak OUTGOING speed of each
    /// shot. Speed is deferred via `ShotSpeedTracker` because at the shot frame
    /// no post-hit samples exist yet.
    func apply(_ result: FrameResult) {
        frameSize = result.frameSize
        fps = result.fps
        trail = result.trail
        latestPoint = result.latestPoint
        shotCount = result.shotCount
        players = PlayerLabeler.assign(result.poses, imageWidth: result.frameSize.width)

        // A detected hit drives both the on-camera flash and the auto-scorer: it's
        // attributed to the side it occurred on (the hitter's side), then a rally
        // that goes quiet awards the point to whoever hit last.
        if let shot = result.shot {
            let side = PlayerLabeler.side(ofHitAt: shot.point, players: players,
                                          imageWidth: result.frameSize.width)
            scorer.registerHit(side: side, time: shot.time)
            shotSeq += 1
            lastShot = ShotMarker(id: shotSeq, point: shot.point)
        }
        scorer.tick(now: result.time)
        scoreP1 = scorer.score(for: .p1)
        scoreP2 = scorer.score(for: .p2)

        speedTracker.update(shotTime: result.shot?.time, now: result.time,
                            samples: result.recentSamples, scale: settings.scale)
        lastSpeed = speedTracker.lastSpeed
        maxSpeed = speedTracker.maxSpeed
    }

    /// Manual score correction (auto detection is experimental).
    func adjustScore(_ side: PlayerSide, by delta: Int) {
        scorer.adjust(side, by: delta)
        scoreP1 = scorer.score(for: .p1)
        scoreP2 = scorer.score(for: .p2)
    }

    func resetScore() {
        scorer.reset()
        scoreP1 = 0
        scoreP2 = 0
    }
}
