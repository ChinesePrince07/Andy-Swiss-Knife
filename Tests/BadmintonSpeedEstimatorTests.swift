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
}
