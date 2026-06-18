import XCTest
@testable import AndySwissKnife

final class BadmintonPlayerLabelerTests: XCTestCase {
    private func pose(x: CGFloat, score: Float) -> PlayerPose {
        // Box centered at x; keypoints/score are all this test needs.
        PlayerPose(box: CGRect(x: x - 20, y: 100, width: 40, height: 120), score: score, keypoints: [])
    }

    /// Leftmost player is P1, rightmost is P2 — regardless of input order.
    func testAssignsLeftP1RightP2() {
        let right = pose(x: 800, score: 0.9)
        let left = pose(x: 200, score: 0.8)
        let labeled = PlayerLabeler.assign([right, left], imageWidth: 1000)
        XCTAssertEqual(labeled.count, 2)
        XCTAssertEqual(labeled[0].side, .p1)
        XCTAssertEqual(labeled[0].pose.box.midX, 200)
        XCTAssertEqual(labeled[1].side, .p2)
        XCTAssertEqual(labeled[1].pose.box.midX, 800)
    }

    /// With extra people detected, only the two highest-score boxes are kept.
    func testPicksTwoHighestScore() {
        let spectator = pose(x: 500, score: 0.2)
        let left = pose(x: 200, score: 0.9)
        let right = pose(x: 800, score: 0.85)
        let labeled = PlayerLabeler.assign([spectator, left, right], imageWidth: 1000)
        XCTAssertEqual(labeled.count, 2)
        XCTAssertEqual(labeled.map(\.pose.box.midX).sorted(), [200, 800])
    }

    /// A lone player is labeled by the image half they stand in.
    func testSinglePlayerByImageHalf() {
        let onRight = PlayerLabeler.assign([pose(x: 700, score: 0.9)], imageWidth: 1000)
        XCTAssertEqual(onRight.first?.side, .p2)
        let onLeft = PlayerLabeler.assign([pose(x: 300, score: 0.9)], imageWidth: 1000)
        XCTAssertEqual(onLeft.first?.side, .p1)
    }

    /// Hits are attributed by the midpoint between the two players.
    func testHitSideByPlayerMidline() {
        let players = [LabeledPose(side: .p1, pose: pose(x: 100, score: 0.9)),
                       LabeledPose(side: .p2, pose: pose(x: 300, score: 0.9))]   // divider = 200
        XCTAssertEqual(PlayerLabeler.side(ofHitAt: CGPoint(x: 150, y: 50), players: players, imageWidth: 1000), .p1)
        XCTAssertEqual(PlayerLabeler.side(ofHitAt: CGPoint(x: 260, y: 50), players: players, imageWidth: 1000), .p2)
    }

    /// With no players known, hits fall back to the image center.
    func testHitSideFallsBackToImageCenter() {
        XCTAssertEqual(PlayerLabeler.side(ofHitAt: CGPoint(x: 400, y: 50), players: [], imageWidth: 1000), .p1)
        XCTAssertEqual(PlayerLabeler.side(ofHitAt: CGPoint(x: 600, y: 50), players: [], imageWidth: 1000), .p2)
    }
}
