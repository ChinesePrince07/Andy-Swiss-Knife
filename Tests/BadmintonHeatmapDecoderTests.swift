import XCTest
@testable import AndySwissKnife

final class BadmintonHeatmapDecoderTests: XCTestCase {
    // Build a heatmap with a Gaussian-ish blob centered at (cx, cy).
    private func blob(_ w: Int, _ h: Int, cx: Int, cy: Int, peak: Float) -> [Float] {
        var hm = [Float](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                let d2 = Float((x - cx) * (x - cx) + (y - cy) * (y - cy))
                hm[y * w + x] = peak * exp(-d2 / 4.0)
            }
        }
        return hm
    }

    func testLocatesBlobCentroid() {
        let w = 512, h = 288
        let hm = blob(w, h, cx: 300, cy: 120, peak: 0.9)
        let r = HeatmapDecoder.locate(heatmap: hm, width: w, height: h, threshold: 0.5)
        XCTAssertNotNil(r)
        XCTAssertEqual(r!.point.x, 300, accuracy: 1.0)
        XCTAssertEqual(r!.point.y, 120, accuracy: 1.0)
        XCTAssertEqual(r!.peak, 0.9, accuracy: 0.01)
    }

    func testNilBelowThreshold() {
        let w = 64, h = 48
        let hm = blob(w, h, cx: 32, cy: 24, peak: 0.3)   // peak 0.3 < threshold 0.5
        XCTAssertNil(HeatmapDecoder.locate(heatmap: hm, width: w, height: h, threshold: 0.5))
    }

    func testNilOnSizeMismatch() {
        XCTAssertNil(HeatmapDecoder.locate(heatmap: [0, 1, 2], width: 2, height: 2, threshold: 0.5))
    }
}
