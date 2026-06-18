import XCTest
@testable import AndySwissKnife

final class BadmintonShuttleGateTests: XCTestCase {
    private let frame = CGSize(width: 1000, height: 1000)
    private let dt = 1.0 / 30.0

    func testAcceptsContinuousMotion() {
        var g = ShuttleGate(maxFractionPerFrame: 0.3, maxMisses: 5)
        XCTAssertTrue(g.accept(CGPoint(x: 100, y: 100), time: 0, frameSize: frame))
        XCTAssertTrue(g.accept(CGPoint(x: 200, y: 120), time: dt, frameSize: frame))    // ~102 px < 300
        XCTAssertTrue(g.accept(CGPoint(x: 300, y: 140), time: 2 * dt, frameSize: frame))
    }

    func testRejectsTeleport() {
        var g = ShuttleGate(maxFractionPerFrame: 0.3, maxMisses: 5)
        XCTAssertTrue(g.accept(CGPoint(x: 100, y: 100), time: 0, frameSize: frame))
        XCTAssertFalse(g.accept(CGPoint(x: 900, y: 900), time: dt, frameSize: frame))   // ~1131 px >> 300
    }

    func testReacquiresAfterMaxMisses() {
        var g = ShuttleGate(maxFractionPerFrame: 0.3, maxMisses: 2)
        XCTAssertTrue(g.accept(CGPoint(x: 100, y: 100), time: 0, frameSize: frame))
        XCTAssertFalse(g.accept(CGPoint(x: 900, y: 900), time: dt, frameSize: frame))       // miss 1
        XCTAssertFalse(g.accept(CGPoint(x: 905, y: 900), time: 2 * dt, frameSize: frame))   // miss 2
        XCTAssertTrue(g.accept(CGPoint(x: 910, y: 900), time: 3 * dt, frameSize: frame))    // re-acquire
    }

    func testFasterMotionAllowedWithLongerGap() {
        var g = ShuttleGate(maxFractionPerFrame: 0.3, maxMisses: 5)
        XCTAssertTrue(g.accept(CGPoint(x: 100, y: 100), time: 0, frameSize: frame))
        // 3 frames elapsed -> allowance triples (~900 px), so a 600 px jump is OK.
        XCTAssertTrue(g.accept(CGPoint(x: 700, y: 100), time: 3 * dt, frameSize: frame))
    }
}
