// Tests/BadmintonTrajectoryTests.swift
import XCTest
@testable import AndySwissKnife

final class BadmintonTrajectoryTests: XCTestCase {
    private func obs(_ x: Double, _ y: Double, _ t: TimeInterval, conf: Double = 1) -> ShuttleObservation {
        ShuttleObservation(point: CGPoint(x: x, y: y), confidence: conf, time: t)
    }

    func testTrailKeepsOnlyWindow() {
        let traj = ShuttleTrajectory(trailWindow: 1.0, maxGap: 0.3)
        traj.add(obs(0, 0, 0.0))
        traj.add(obs(10, 0, 0.5))
        traj.add(obs(20, 0, 1.2))   // 1.2s; prunes the 0.0s sample (older than 1.0s window)
        XCTAssertEqual(traj.trail, [CGPoint(x: 10, y: 0), CGPoint(x: 20, y: 0)])
    }

    func testVelocityFromLastTwoSamples() {
        let traj = ShuttleTrajectory()
        traj.add(obs(0, 0, 0.0))
        traj.add(obs(100, 0, 0.1))    // 100px in 0.1s -> 1000 px/s on x
        let v = traj.velocity()
        XCTAssertNotNil(v)
        XCTAssertEqual(v!.dx, 1000, accuracy: 0.001)
        XCTAssertEqual(v!.dy, 0, accuracy: 0.001)
    }

    func testVelocityNilAcrossLargeGap() {
        let traj = ShuttleTrajectory(trailWindow: 5.0, maxGap: 0.3)
        traj.add(obs(0, 0, 0.0))
        traj.add(obs(100, 0, 1.0))    // gap 1.0s > maxGap -> no velocity
        XCTAssertNil(traj.velocity())
    }
}
