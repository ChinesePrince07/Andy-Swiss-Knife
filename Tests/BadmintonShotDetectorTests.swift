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

    func testDetectsHorizontalReversal() {
        let det = ShotDetector(minPixelSpeed: 300, refractory: 0.2)
        // moving right (+x) fast, then reversing to left (-x) fast at t=0.3
        let events = feed(det, [
            (0, 100, 0.0), (100, 100, 0.1), (200, 100, 0.2), // rightward ~1000 px/s
            (120, 100, 0.3), (40, 100, 0.4)                   // leftward ~800 px/s
        ])
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(det.shotCount, 1)
    }

    func testNoShotBelowSpeed() {
        let det = ShotDetector(minPixelSpeed: 300, refractory: 0.2)
        // slow drift reversal -> not a shot
        let events = feed(det, [
            (0, 100, 0.0), (10, 100, 0.1), (20, 100, 0.2),
            (15, 100, 0.3), (10, 100, 0.4)
        ])
        XCTAssertEqual(events.count, 0)
    }

    func testRefractorySuppressesDoubleCount() {
        let det = ShotDetector(minPixelSpeed: 300, refractory: 0.5)
        let events = feed(det, [
            (0, 100, 0.0), (100, 100, 0.1), (200, 100, 0.2),
            (120, 100, 0.3),                 // reversal #1 -> shot at 0.3
            (220, 100, 0.4), (300, 100, 0.5) // reversal #2 within 0.5s refractory -> suppressed
        ])
        XCTAssertEqual(events.count, 1)
    }
}
