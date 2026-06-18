import SwiftUI

struct OverlayRenderer: View {
    let trail: [CGPoint]
    let latest: CGPoint?
    let poses: [PlayerPose]
    let imageSize: CGSize
    let accent: Color

    private static let playerColors: [Color] = [.green, .cyan, .orange, .pink]
    private static let kptThreshold: Float = 0.3

    var body: some View {
        Canvas { ctx, size in
            guard imageSize.width > 0, imageSize.height > 0 else { return }
            let scale = min(size.width / imageSize.width, size.height / imageSize.height)
            let offX = (size.width - imageSize.width * scale) / 2
            let offY = (size.height - imageSize.height * scale) / 2
            func map(_ p: CGPoint) -> CGPoint {
                CGPoint(x: offX + p.x * scale, y: offY + p.y * scale)
            }

            // Player skeletons (drawn under the shuttle trail).
            for (i, pose) in poses.enumerated() {
                let color = Self.playerColors[i % Self.playerColors.count]
                var bones = Path()
                for (a, b) in PlayerPose.skeleton {
                    guard a < pose.keypoints.count, b < pose.keypoints.count else { continue }
                    let ka = pose.keypoints[a], kb = pose.keypoints[b]
                    if ka.confidence < Self.kptThreshold || kb.confidence < Self.kptThreshold { continue }
                    bones.move(to: map(ka.point))
                    bones.addLine(to: map(kb.point))
                }
                ctx.stroke(bones, with: .color(color), lineWidth: 3)
                for kp in pose.keypoints where kp.confidence >= Self.kptThreshold {
                    let c = map(kp.point), r: CGFloat = 3
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                             with: .color(color))
                }
            }

            // Shuttle trail + current marker.
            if trail.count >= 2 {
                var path = Path()
                path.move(to: map(trail[0]))
                for p in trail.dropFirst() { path.addLine(to: map(p)) }
                ctx.stroke(path, with: .color(accent), lineWidth: 3)
            }
            if let latest {
                let c = map(latest)
                let r: CGFloat = 7
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                         with: .color(accent))
            }
        }
        .allowsHitTesting(false)
    }
}
