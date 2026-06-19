import SwiftUI

struct OverlayRenderer: View {
    let trail: [CGPoint]
    let latest: CGPoint?
    let players: [LabeledPose]
    let imageSize: CGSize
    let accent: Color
    var roi: CGRect? = nil   // normalized court region (drawn faintly when set)

    private static let kptThreshold: Float = 0.3

    private static func color(_ side: PlayerSide) -> Color {
        side == .p1 ? .green : .cyan
    }

    var body: some View {
        GeometryReader { geo in
            let fit = AspectFit(image: imageSize, in: geo.size)
            ZStack {
                Canvas { ctx, size in
                    guard imageSize.width > 0, imageSize.height > 0 else { return }
                    draw(in: ctx, fit: AspectFit(image: imageSize, in: size))
                }
                // P1 / P2 tags as real Text views (crisp, and avoids styling text
                // inside the Canvas).
                if imageSize.width > 0 {
                    ForEach(players.indices, id: \.self) { i in
                        let lp = players[i]
                        let box = fit.map(lp.pose.box)
                        Text(lp.side == .p1 ? "P1" : "P2")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Self.color(lp.side))
                            .shadow(color: .black, radius: 1)
                            .position(x: box.minX + 14, y: max(8, box.minY - 9))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(in ctx: GraphicsContext, fit: AspectFit) {
        // Court region (faint), if set — detections outside it are ignored.
        if let roi {
            let px = CGRect(x: roi.minX * imageSize.width, y: roi.minY * imageSize.height,
                            width: roi.width * imageSize.width, height: roi.height * imageSize.height)
            ctx.stroke(Path(fit.map(px)), with: .color(.white.opacity(0.3)), lineWidth: 1.5)
        }

        // Player bounding boxes + skeletons (under the shuttle trail).
        for labeled in players {
            let color = Self.color(labeled.side)
            let pose = labeled.pose

            ctx.stroke(Path(fit.map(pose.box)), with: .color(color), lineWidth: 2)

            var bones = Path()
            for (a, b) in PlayerPose.skeleton {
                guard a < pose.keypoints.count, b < pose.keypoints.count else { continue }
                let ka = pose.keypoints[a], kb = pose.keypoints[b]
                if ka.confidence < Self.kptThreshold || kb.confidence < Self.kptThreshold { continue }
                bones.move(to: fit.map(ka.point))
                bones.addLine(to: fit.map(kb.point))
            }
            ctx.stroke(bones, with: .color(color), lineWidth: 3)
            for kp in pose.keypoints where kp.confidence >= Self.kptThreshold {
                let c = fit.map(kp.point), r: CGFloat = 3
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                         with: .color(color))
            }
        }

        // Shuttle trail + current marker.
        if trail.count >= 2 {
            var path = Path()
            path.move(to: fit.map(trail[0]))
            for p in trail.dropFirst() { path.addLine(to: fit.map(p)) }
            ctx.stroke(path, with: .color(accent), lineWidth: 3)
        }
        if let latest {
            let c = fit.map(latest)
            let r: CGFloat = 7
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                     with: .color(accent))
        }
    }
}
