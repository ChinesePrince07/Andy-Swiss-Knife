import CoreGraphics

/// A detected player with a stable P1/P2 identity.
struct LabeledPose: Sendable {
    let side: PlayerSide
    let pose: PlayerPose
}

/// Assigns stable P1/P2 identities to detected players and attributes hits to a
/// side. Side-on at net height, the two players split left/right in the image, so
/// identity is purely by horizontal position. Pure + deterministic for CI tests.
enum PlayerLabeler {
    /// Pick the two most-confident players and label them by horizontal position:
    /// leftmost = P1, rightmost = P2. A lone player is labeled by which image half
    /// they stand in. Extra detections (spectators) are dropped.
    static func assign(_ poses: [PlayerPose], imageWidth: CGFloat) -> [LabeledPose] {
        let ordered = poses
            .sorted { $0.score > $1.score }
            .prefix(2)
            .sorted { $0.box.midX < $1.box.midX }

        if ordered.count >= 2 {
            return [LabeledPose(side: .p1, pose: ordered[0]),
                    LabeledPose(side: .p2, pose: ordered[1])]
        }
        if let only = ordered.first {
            let side: PlayerSide = only.box.midX < imageWidth / 2 ? .p1 : .p2
            return [LabeledPose(side: side, pose: only)]
        }
        return []
    }

    /// Attribute a hit to the side it occurred on. The dividing line is the midpoint
    /// between the two players (the net, side-on) when both are known, else the
    /// image center. A hit lands on the hitter's own side, so this names the hitter.
    static func side(ofHitAt point: CGPoint, players: [LabeledPose], imageWidth: CGFloat) -> PlayerSide {
        let p1x = players.first { $0.side == .p1 }?.pose.box.midX
        let p2x = players.first { $0.side == .p2 }?.pose.box.midX
        let divider: CGFloat
        if let a = p1x, let b = p2x {
            divider = (a + b) / 2
        } else {
            divider = imageWidth / 2
        }
        return point.x < divider ? .p1 : .p2
    }
}
