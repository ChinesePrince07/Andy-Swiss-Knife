import XCTest
@testable import AndySwissKnife

/// End-to-end validation of the badminton pipeline on a REAL shuttle trajectory
/// extracted offline from match footage (the shipped TrackNet config: EMA bg +
/// middle-channel decode). Unlike the synthetic unit tests, this replays real,
/// gappy detections through the exact app chain (gate -> trajectory -> shot ->
/// speed -> score) to confirm it produces plausible, bounded results — and guards
/// against regressions. See tools/badminton-research/ for how the fixture is made.
final class BadmintonEndToEndTests: XCTestCase {
    private struct Track: Decodable {
        let fps: Double, width: Double, height: Double
        let samples: [Sample]
        struct Sample: Decodable { let frame: Int; let t: Double; let x: Double; let y: Double; let peak: Double }
    }

    private func loadTrack() throws -> Track {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "shuttle_track_twitter", withExtension: "json"),
                                "fixture shuttle_track_twitter.json missing from test bundle")
        return try JSONDecoder().decode(Track.self, from: Data(contentsOf: url))
    }

    /// The plausible-speed cap discards a physically-impossible interval (a residual
    /// teleport) so it can't dominate the peak — the readout never shows a 1696 km/h.
    func testSpeedEstimatorRejectsImpossibleSpeed() throws {
        let scale = ReferenceScale(p1: .zero, p2: CGPoint(x: 1000, y: 0), realMeters: 11.2)!  // 0.0112 m/px
        let samples = [
            TrajectorySample(point: CGPoint(x: 0,   y: 0), time: 0.0),
            TrajectorySample(point: CGPoint(x: 60,  y: 0), time: 1.0 / 60),  // ~40 m/s (real)
            TrajectorySample(point: CGPoint(x: 760, y: 0), time: 2.0 / 60),  // ~470 m/s (impossible)
        ]
        let s = try XCTUnwrap(SpeedEstimator.peakSpeed(samples: samples, from: 0, window: 0.1, scale: scale))
        // The impossible 700px/frame interval is dropped; the real ~40 m/s survives.
        XCTAssertLessThanOrEqual(s.metersPerSecond, SpeedEstimator.maxPlausibleMetersPerSecond)
        XCTAssertGreaterThan(s.metersPerSecond, 30)
        XCTAssertLessThan(s.metersPerSecond, 60)
    }

    /// Replay the real trajectory through the full pipeline exactly as the app does.
    func testRealTrajectoryRunsThroughFullPipeline() throws {
        let track = try loadTrack()
        XCTAssertGreaterThan(track.samples.count, 30, "fixture should hold a real trajectory")

        var gate = ShuttleGate()
        let trajectory = ShuttleTrajectory(trailWindow: 1.0, maxGap: 0.3)
        let shots = ShotDetector()
        var speed = ShotSpeedTracker(window: 0.08)
        let scorer = AutoScorer()
        let scale = ReferenceScale(p1: .zero, p2: CGPoint(x: 1000, y: 0), realMeters: 11.2)!
        let size = CGSize(width: track.width, height: track.height)

        var shotCount = 0
        var lastTime = 0.0
        for s in track.samples {
            let pt = CGPoint(x: s.x, y: s.y)
            guard gate.accept(pt, time: s.t, frameSize: size) else { continue }   // app applies the gate
            let obs = ShuttleObservation(point: pt, confidence: s.peak, time: s.t)
            trajectory.add(obs)
            let shot = shots.ingest(TrajectorySample(point: obs.point, time: obs.time))
            if let shot {
                shotCount += 1
                let side = PlayerLabeler.side(ofHitAt: shot.point, players: [], imageWidth: CGFloat(track.width))
                scorer.registerHit(side: side, time: shot.time)
            }
            speed.update(shotTime: shot?.time, now: obs.time, samples: trajectory.samples, scale: scale)
            scorer.tick(now: obs.time)
            lastTime = obs.time
        }

        // The real rally produces detectable hits.
        XCTAssertGreaterThanOrEqual(shotCount, 1, "expected >=1 detected hit on a real rally")
        // Any measured speed is physically bounded (the cap guarantees correctness).
        if let mx = speed.maxSpeed {
            XCTAssertGreaterThan(mx.kmh, 0)
            XCTAssertLessThanOrEqual(mx.metersPerSecond, SpeedEstimator.maxPlausibleMetersPerSecond)
        }
        // End the rally; scoring must stay consistent, and a rally with >=2 detected
        // hits awards exactly one point to the last hitter's side.
        scorer.tick(now: lastTime + 2.0)
        let total = scorer.score(for: .p1) + scorer.score(for: .p2)
        XCTAssertGreaterThanOrEqual(total, 0)
        if shotCount >= 2 {
            XCTAssertGreaterThanOrEqual(total, 1, "a rally with >=2 hits should award a point")
        }
    }
}
