// Sources/Views/Badminton/OverlayRenderer.swift
import SwiftUI

struct OverlayRenderer: View {
    let trail: [CGPoint]
    let latest: CGPoint?
    let imageSize: CGSize
    let accent: Color

    var body: some View {
        Canvas { ctx, size in
            guard imageSize.width > 0, imageSize.height > 0 else { return }
            let scale = min(size.width / imageSize.width, size.height / imageSize.height)
            let offX = (size.width - imageSize.width * scale) / 2
            let offY = (size.height - imageSize.height * scale) / 2
            func map(_ p: CGPoint) -> CGPoint {
                CGPoint(x: offX + p.x * scale, y: offY + p.y * scale)
            }
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
