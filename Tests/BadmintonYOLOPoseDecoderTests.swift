import XCTest
@testable import AndySwissKnife

final class BadmintonYOLOPoseDecoderTests: XCTestCase {
    func testDecodesAndAppliesNMS() {
        let n = 3
        var raw = [Float](repeating: 0, count: 56 * n)
        func set(_ c: Int, _ a: Int, _ v: Float) { raw[c * n + a] = v }

        // Anchor 0: strong person, box center (320,320) size 100x200.
        set(0, 0, 320); set(1, 0, 320); set(2, 0, 100); set(3, 0, 200); set(4, 0, 0.9)
        for k in 0..<17 { set(5 + 3 * k, 0, 320); set(5 + 3 * k + 1, 0, 300); set(5 + 3 * k + 2, 0, 0.9) }
        // Anchor 1: overlaps anchor 0, lower conf -> suppressed by NMS.
        set(0, 1, 325); set(1, 1, 320); set(2, 1, 100); set(3, 1, 200); set(4, 1, 0.8)
        // Anchor 2: below threshold -> filtered.
        set(4, 2, 0.1)

        let poses = YOLOPoseDecoder.decode(raw: raw, numAnchors: n, inputSize: 640,
                                           confThreshold: 0.4, iouThreshold: 0.45)
        XCTAssertEqual(poses.count, 1)
        XCTAssertEqual(poses[0].score, 0.9, accuracy: 0.001)
        XCTAssertEqual(poses[0].box.midX, 0.5, accuracy: 0.01)          // 320/640
        XCTAssertEqual(poses[0].box.width, 100.0 / 640, accuracy: 0.001)
        XCTAssertEqual(poses[0].keypoints.count, 17)
        XCTAssertEqual(poses[0].keypoints[0].point.x, 0.5, accuracy: 0.01)
        XCTAssertEqual(poses[0].keypoints[0].point.y, 300.0 / 640, accuracy: 0.01)
    }

    func testFiltersAllBelowThreshold() {
        let n = 2
        var raw = [Float](repeating: 0, count: 56 * n)
        raw[4 * n + 0] = 0.2; raw[4 * n + 1] = 0.1   // both < 0.4
        XCTAssertTrue(YOLOPoseDecoder.decode(raw: raw, numAnchors: n, inputSize: 640).isEmpty)
    }

    func testEmptyOnSizeMismatch() {
        XCTAssertTrue(YOLOPoseDecoder.decode(raw: [1, 2, 3], numAnchors: 8400, inputSize: 640).isEmpty)
    }
}
