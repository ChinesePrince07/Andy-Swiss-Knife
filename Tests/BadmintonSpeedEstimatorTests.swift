import XCTest
@testable import AndySwissKnife

final class BadmintonSpeedEstimatorTests: XCTestCase {
    func testPeakSpeedConstantVelocity() {
        // 0.01 m/px. 500 px between frames, dt=1/120s -> 5 m * 120 = 600 m/s? scale it down:
        // Use 100 px/frame at 0.01 m/px = 1 m/frame, dt = 1/120 -> 120 m/s.
        let scale = ReferenceScale(p1: CGPoint(x: 0, y: 0), p2: CGPoint(x: 100, y: 0), realMeters: 1.0)! // 0.01 m/px
        let dt = 1.0 / 120.0
        let samples = (0..<6).map { i in
            TrajectorySample(point: CGPoint(x: Double(i) * 100, y: 0), time: Double(i) * dt)
        }
        let speed = SpeedEstimator.peakSpeed(samples: samples, from: 0, window: 0.08, scale: scale)
        XCTAssertNotNil(speed)
        XCTAssertEqual(speed!.metersPerSecond, 120, accuracy: 1.0)
        XCTAssertEqual(speed!.kmh, 432, accuracy: 4.0)
    }

    func testNilWhenTooFewSamples() {
        let scale = ReferenceScale(p1: .zero, p2: CGPoint(x: 100, y: 0), realMeters: 1.0)!
        let samples = [TrajectorySample(point: .zero, time: 0)]
        XCTAssertNil(SpeedEstimator.peakSpeed(samples: samples, from: 0, window: 0.08, scale: scale))
    }

    /// A single-frame teleport spike (a detection error that slips under the trail
    /// gate) must NOT define the peak — only speed sustained across ≥2 consecutive
    /// frames counts. This is the fix for the gate-ceiling artifact that pinned the
    /// readout at a false ~400 km/h on real footage.
    func testRejectsSingleFrameTeleportSpike() throws {
        let scale = ReferenceScale(p1: .zero, p2: CGPoint(x: 100, y: 0), realMeters: 1.0)! // 0.01 m/px
        let dt = 1.0 / 120.0
        // Slow ~30 px/frame motion with ONE 1200 px teleport jump at index 3.
        let xs: [Double] = [0, 30, 60, 1260, 1290, 1320]
        let samples = xs.enumerated().map { (i, x) in
            TrajectorySample(point: CGPoint(x: x, y: 0), time: Double(i) * dt)
        }
        let speed = try XCTUnwrap(SpeedEstimator.peakSpeed(samples: samples, from: 0, window: 0.08, scale: scale))
        // The real motion is ~36 m/s; the isolated 1440 m/s spike is rejected.
        XCTAssertGreaterThan(speed.metersPerSecond, 30)
        XCTAssertLessThan(speed.metersPerSecond, 50)
    }
}
