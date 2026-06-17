import XCTest
@testable import AndySwissKnife

final class BadmintonFPSCounterTests: XCTestCase {
    func testThirtyFps() {
        let c = FPSCounter(window: 1.0)
        for i in 0..<31 { c.tick(at: Double(i) / 30.0) }   // ticks every 1/30s over ~1s
        XCTAssertEqual(c.fps, 30, accuracy: 1.0)
    }

    func testZeroWithOneTick() {
        let c = FPSCounter()
        c.tick(at: 5.0)
        XCTAssertEqual(c.fps, 0)
    }
}
