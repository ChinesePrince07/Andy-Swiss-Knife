// Sources/Services/Badminton/BadmintonEngine.swift
import Observation
import CoreGraphics
import CoreVideo
import Foundation

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

    /// Fired on each detected shot (P2 uses this to measure speed).
    var onShot: ((ShotEvent, ShuttleTrajectory) -> Void)?

    let captureFPS: Int
    let camera = CameraSession()
    private let detector: ShuttleDetector
    private let trajectory = ShuttleTrajectory(trailWindow: 1.0, maxGap: 0.3)
    private let shots = ShotDetector()
    private let fpsCounter = FPSCounter()
    private let processQueue = DispatchQueue(label: "badminton.process")

    init(detector: ShuttleDetector = MotionShuttleDetector(), captureFPS: Int = 60) {
        self.detector = detector
        self.captureFPS = captureFPS
        camera.onFrame = { [weak self] buffer, time in
            self?.handleFrame(buffer, time: time)
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

    // Runs on the camera's delivery queue.
    private nonisolated func handleFrame(_ buffer: CVPixelBuffer, time: TimeInterval) {
        let w = CVPixelBufferGetWidth(buffer)
        let h = CVPixelBufferGetHeight(buffer)
        let obs = detector.detect(pixelBuffer: buffer, time: time)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.frameSize = CGSize(width: w, height: h)
            self.fpsCounter.tick(at: time)
            self.fps = self.fpsCounter.fps
            guard let obs else { self.latestPoint = nil; return }
            self.trajectory.add(obs)
            self.trail = self.trajectory.trail
            self.latestPoint = obs.point
            let sample = TrajectorySample(point: obs.point, time: obs.time)
            if let shot = self.shots.ingest(sample) {
                self.shotCount = self.shots.shotCount
                self.onShot?(shot, self.trajectory)
            }
        }
    }
}
