import XCTest
@testable import AndySwissKnife

final class BadmintonBlobFinderTests: XCTestCase {
    // Build a WxH diff image with a bright square centered at (cx,cy).
    private func image(_ w: Int, _ h: Int, square cx: Int, _ cy: Int, half: Int, value: UInt8) -> [UInt8] {
        var px = [UInt8](repeating: 0, count: w * h)
        for y in (cy - half)...(cy + half) {
            for x in (cx - half)...(cx + half) where x >= 0 && x < w && y >= 0 && y < h {
                px[y * w + x] = value
            }
        }
        return px
    }

    func testFindsBrightSquareCentroid() {
        let w = 64, h = 48
        let img = image(w, h, square: 40, 20, half: 1, value: 255)   // 3x3 bright = area 9
        let blob = MotionBlobFinder.brightestBlob(
            diff: img, width: w, height: h, threshold: 64,
            minArea: 1, maxArea: 200, near: nil, searchRadius: 9999)
        XCTAssertNotNil(blob)
        XCTAssertEqual(blob!.point.x, 40, accuracy: 1.0)
        XCTAssertEqual(blob!.point.y, 20, accuracy: 1.0)
        XCTAssertEqual(blob!.peak, 255)
    }

    func testRejectsTooLargeBlob() {
        let w = 64, h = 48
        let img = image(w, h, square: 32, 24, half: 10, value: 255)  // 21x21 = area 441
        let blob = MotionBlobFinder.brightestBlob(
            diff: img, width: w, height: h, threshold: 64,
            minArea: 1, maxArea: 100, near: nil, searchRadius: 9999)
        XCTAssertNil(blob)
    }

    func testNilWhenBelowThreshold() {
        let w = 32, h = 32
        let img = image(w, h, square: 16, 16, half: 1, value: 40)
        let blob = MotionBlobFinder.brightestBlob(
            diff: img, width: w, height: h, threshold: 64,
            minArea: 1, maxArea: 100, near: nil, searchRadius: 9999)
        XCTAssertNil(blob)
    }
}
