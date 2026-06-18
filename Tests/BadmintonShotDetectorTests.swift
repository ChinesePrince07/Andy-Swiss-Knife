import XCTest
@testable import AndySwissKnife

final class BadmintonShotDetectorTests: XCTestCase {
    private func feed(_ det: ShotDetector, _ pts: [(Double, Double, TimeInterval)]) -> [ShotEvent] {
        var events: [ShotEvent] = []
        for (x, y, t) in pts {
            if let e = det.ingest(TrajectorySample(point: CGPoint(x: x, y: y), time: t)) { events.append(e) }
        }
        return events
    }

    /// A sustained rightward run then a sustained leftward run = two strokes.
    func testCountsSustainedReversal() {
        let det = ShotDetector(minPixelSpeed: 350, minRun: 3, refractory: 0.12)
        let events = feed(det, [
            (0, 100, 0.0), (100, 100, 0.05), (200, 100, 0.10), (300, 100, 0.15),  // right run
            (200, 100, 0.20), (100, 100, 0.25), (0, 100, 0.30)                    // left run
        ])
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(det.shotCount, 2)
    }

    /// THE regression for the on-device bug: frame-difference noise jumps to random
    /// positions, flipping horizontal direction nearly every frame. The old
    /// single-frame-reversal detector counted each flip as a shot; the run-based
    /// detector must count ZERO, because no direction sustains `minRun` frames.
    func testRejectsErraticNoise() {
        let det = ShotDetector(minPixelSpeed: 350, minRun: 3, refractory: 0.12)
        let events = feed(det, [
            (0, 100, 0.00), (200, 100, 0.05), (0, 100, 0.10), (200, 100, 0.15),
            (0, 100, 0.20), (200, 100, 0.25), (0, 100, 0.30), (200, 100, 0.35)
        ])
        XCTAssertEqual(events.count, 0)
        XCTAssertEqual(det.shotCount, 0)
    }

    /// A single slow frame mid-run (e.g. near the apex) must not break the run.
    func testIgnoresSingleSlowBlipMidRun() {
        let det = ShotDetector(minPixelSpeed: 350, minRun: 3, refractory: 0.12)
        let events = feed(det, [
            (0, 100, 0.00), (100, 100, 0.05), (200, 100, 0.10),
            (210, 100, 0.15),                                   // slow blip (|vx| < 350) -> ignored
            (310, 100, 0.20), (410, 100, 0.25)                  // run continues -> one stroke
        ])
        XCTAssertEqual(events.count, 1)
    }

    /// Slow drift in both directions is never a shot.
    func testNoShotWhenAllSlow() {
        let det = ShotDetector(minPixelSpeed: 350, minRun: 3, refractory: 0.12)
        let events = feed(det, [
            (0, 100, 0.0), (10, 100, 0.05), (20, 100, 0.10), (15, 100, 0.15), (10, 100, 0.20)
        ])
        XCTAssertEqual(events.count, 0)
    }
}
