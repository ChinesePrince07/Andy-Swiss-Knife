import XCTest
@testable import AndySwissKnife

final class BadmintonShotSpeedTrackerTests: XCTestCase {
    // 100 px == 1.0 m -> 0.01 m/px.
    private let scale = ReferenceScale(p1: .zero, p2: CGPoint(x: 100, y: 0), realMeters: 1.0)!
    private let dt = 1.0 / 120.0

    /// Reproduces the bug the final review caught: at the shot frame the only
    /// sample is the shot itself, so no speed can be measured yet — but once the
    /// outgoing (post-hit) samples arrive, the peak speed is recovered.
    func testNoSpeedAtShotFrameThenComputesAfterPostHitSamples() {
        var tracker = ShotSpeedTracker(window: 0.08)

        // Shot frame: newest (only forward) sample IS at the shot time.
        var samples = [TrajectorySample(point: CGPoint(x: 500, y: 0), time: 0)]
        tracker.update(shotTime: 0, now: 0, samples: samples, scale: scale)
        XCTAssertNil(tracker.lastSpeed, "no post-hit samples exist yet at the shot frame")

        // Outgoing smash: 100 px/frame at 0.01 m/px, dt = 1/120 -> 120 m/s.
        for i in 1...6 {
            samples.append(TrajectorySample(point: CGPoint(x: 500 + Double(i) * 100, y: 0), time: Double(i) * dt))
            tracker.update(shotTime: nil, now: Double(i) * dt, samples: samples, scale: scale)
        }
        XCTAssertNotNil(tracker.lastSpeed, "speed is recovered once post-hit samples arrive")
        XCTAssertEqual(tracker.lastSpeed!.metersPerSecond, 120, accuracy: 2.0)
        XCTAssertEqual(tracker.maxSpeed!.metersPerSecond, 120, accuracy: 2.0)
    }

    func testNoSpeedWithoutScale() {
        var tracker = ShotSpeedTracker(window: 0.08)
        var samples = [TrajectorySample(point: .zero, time: 0)]
        tracker.update(shotTime: 0, now: 0, samples: samples, scale: nil)
        for i in 1...6 {
            samples.append(TrajectorySample(point: CGPoint(x: Double(i) * 100, y: 0), time: Double(i) * dt))
            tracker.update(shotTime: nil, now: Double(i) * dt, samples: samples, scale: nil)
        }
        XCTAssertNil(tracker.lastSpeed)
    }

    func testResetClearsSpeeds() {
        var tracker = ShotSpeedTracker(window: 0.08)
        var samples = [TrajectorySample(point: .zero, time: 0)]
        tracker.update(shotTime: 0, now: 0, samples: samples, scale: scale)
        for i in 1...12 {   // run well past the 0.08 s window
            samples.append(TrajectorySample(point: CGPoint(x: Double(i) * 100, y: 0), time: Double(i) * dt))
            tracker.update(shotTime: nil, now: Double(i) * dt, samples: samples, scale: scale)
        }
        XCTAssertNotNil(tracker.maxSpeed)
        tracker.resetSpeeds()
        XCTAssertNil(tracker.lastSpeed)
        XCTAssertNil(tracker.maxSpeed)
    }
}
