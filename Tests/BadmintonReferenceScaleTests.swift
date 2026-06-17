import XCTest
@testable import AndySwissKnife

final class BadmintonReferenceScaleTests: XCTestCase {
    func testScaleFromNetHeight() {
        // 200px segment represents 1.55m -> 0.00775 m/px
        let s = ReferenceScale(p1: CGPoint(x: 100, y: 400), p2: CGPoint(x: 100, y: 200), realMeters: 1.55)
        XCTAssertNotNil(s)
        XCTAssertEqual(s!.metersPerPixel, 1.55 / 200, accuracy: 1e-9)
        XCTAssertEqual(s!.meters(pixels: 400), 1.55 / 200 * 400, accuracy: 1e-9)
    }

    func testMetersBetweenPoints() {
        let s = ReferenceScale(p1: CGPoint(x: 0, y: 0), p2: CGPoint(x: 100, y: 0), realMeters: 1.0)!
        XCTAssertEqual(s.meters(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: 50)), 0.5, accuracy: 1e-9)
    }

    func testNilOnDegenerate() {
        XCTAssertNil(ReferenceScale(p1: CGPoint(x: 5, y: 5), p2: CGPoint(x: 5, y: 5), realMeters: 1.55))
        XCTAssertNil(ReferenceScale(p1: CGPoint(x: 0, y: 0), p2: CGPoint(x: 10, y: 0), realMeters: 0))
    }
}
