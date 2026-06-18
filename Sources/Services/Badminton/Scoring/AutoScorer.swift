import Foundation

/// Which side of the (side-on) court a player / hit belongs to.
enum PlayerSide: Sendable, Equatable {
    case p1   // left half of the image
    case p2   // right half
}

/// Experimental no-court auto-scorer.
///
/// A *rally* is a run of detected hits. When no new hit arrives for `endTimeout`,
/// the rally is over and the player who hit the shuttle **last** is awarded the
/// point — the premise being that their opponent failed to return it. This rides
/// the (already noise-filtered) hit signal rather than a landing call, which would
/// need a calibrated court.
///
/// Rules are intentionally a simple tally: two integer counters, no game/match/
/// serve logic. Auto detection is unreliable, so every count is correctable via
/// `adjust`. Pure and deterministic — driven entirely by `registerHit`/`tick`/
/// `now` — so it is fully unit-testable in CI without a device.
final class AutoScorer {
    let endTimeout: TimeInterval
    let minHits: Int

    private(set) var p1 = 0
    private(set) var p2 = 0

    private var lastHitSide: PlayerSide?
    private var lastHitTime: TimeInterval = 0
    private var hitsThisRally = 0

    /// - Parameters:
    ///   - endTimeout: silence (no new hit) that ends a rally.
    ///   - minHits: hits a rally needs before it can score (rejects a stray
    ///     single hit during warm-up from awarding a point).
    init(endTimeout: TimeInterval = 1.2, minHits: Int = 2) {
        self.endTimeout = endTimeout
        self.minHits = max(1, minHits)
    }

    func score(for side: PlayerSide) -> Int { side == .p1 ? p1 : p2 }

    /// Record a detected hit attributed to `side`.
    func registerHit(side: PlayerSide, time: TimeInterval) {
        lastHitSide = side
        lastHitTime = time
        hitsThisRally += 1
    }

    /// Advance the clock. Returns the side awarded a point if a rally ended on
    /// this tick, else nil.
    @discardableResult
    func tick(now: TimeInterval) -> PlayerSide? {
        guard let side = lastHitSide,
              hitsThisRally >= minHits,
              now - lastHitTime >= endTimeout else { return nil }
        award(side)
        endRally()
        return side
    }

    /// Manual correction (auto detection is experimental). Clamped at 0.
    func adjust(_ side: PlayerSide, by delta: Int) {
        switch side {
        case .p1: p1 = max(0, p1 + delta)
        case .p2: p2 = max(0, p2 + delta)
        }
    }

    /// Clear both scores and any in-progress rally.
    func reset() {
        p1 = 0
        p2 = 0
        endRally()
    }

    private func award(_ side: PlayerSide) {
        switch side {
        case .p1: p1 += 1
        case .p2: p2 += 1
        }
    }

    private func endRally() {
        lastHitSide = nil
        hitsThisRally = 0
    }
}
