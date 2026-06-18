import XCTest
@testable import AndySwissKnife

final class BadmintonAutoScorerTests: XCTestCase {
    /// Two hits (p1 then p2), then silence past the timeout → the LAST hitter (p2)
    /// is awarded the point.
    func testAwardsLastHitterAfterTimeout() {
        let s = AutoScorer(endTimeout: 1.2, minHits: 2)
        s.registerHit(side: .p1, time: 0.0)
        s.registerHit(side: .p2, time: 0.3)
        XCTAssertNil(s.tick(now: 1.0))              // 1.0 - 0.3 < 1.2: rally still live
        XCTAssertEqual(s.tick(now: 1.5), .p2)       // 1.5 - 0.3 >= 1.2: rally ends
        XCTAssertEqual(s.score(for: .p2), 1)
        XCTAssertEqual(s.score(for: .p1), 0)
    }

    /// A rally with fewer than `minHits` hits never scores (rejects a stray hit).
    func testNoAwardBelowMinHits() {
        let s = AutoScorer(endTimeout: 1.2, minHits: 2)
        s.registerHit(side: .p1, time: 0.0)
        XCTAssertNil(s.tick(now: 5.0))
        XCTAssertEqual(s.score(for: .p1), 0)
    }

    /// After an award the rally resets: a fresh single hit can't immediately score,
    /// and the previous award is not repeated on later ticks.
    func testRallyResetsAfterAwardAndNoDoubleAward() {
        let s = AutoScorer(endTimeout: 1.0, minHits: 2)
        s.registerHit(side: .p1, time: 0.0)
        s.registerHit(side: .p1, time: 0.2)
        XCTAssertEqual(s.tick(now: 1.3), .p1)       // awarded
        XCTAssertNil(s.tick(now: 2.0))              // no double-award
        XCTAssertEqual(s.score(for: .p1), 1)

        s.registerHit(side: .p2, time: 3.0)         // new rally, single hit
        XCTAssertNil(s.tick(now: 5.0))              // below minHits → no score
        s.registerHit(side: .p2, time: 5.1)
        XCTAssertEqual(s.tick(now: 6.5), .p2)       // two hits → scores
        XCTAssertEqual(s.score(for: .p2), 1)
    }

    /// Manual adjust raises/lowers a side and clamps at zero.
    func testAdjustClampsAtZero() {
        let s = AutoScorer()
        s.adjust(.p1, by: 3)
        XCTAssertEqual(s.score(for: .p1), 3)
        s.adjust(.p1, by: -10)
        XCTAssertEqual(s.score(for: .p1), 0)
        s.adjust(.p2, by: 1)
        XCTAssertEqual(s.score(for: .p2), 1)
    }

    /// Reset clears scores and any in-progress rally (so a pending hit can't score
    /// the next tick).
    func testResetClearsScoresAndRally() {
        let s = AutoScorer(endTimeout: 1.0, minHits: 1)
        s.adjust(.p1, by: 5)
        s.registerHit(side: .p2, time: 0.0)
        s.reset()
        XCTAssertEqual(s.score(for: .p1), 0)
        XCTAssertEqual(s.score(for: .p2), 0)
        XCTAssertNil(s.tick(now: 10.0))             // rally was cleared
    }
}
