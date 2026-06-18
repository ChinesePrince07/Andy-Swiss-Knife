import SwiftUI

/// A detected hit to visualize: a stable `id` (so each new hit re-fires the
/// animation) and the image-space point where it was detected.
struct ShotMarker: Equatable, Sendable {
    let id: Int
    let point: CGPoint
}

/// Pulses an expanding ring + `HIT` tag at the shuttle every time a hit is
/// detected — the live, on-camera confirmation that shot detection is firing
/// (and where). Keyed on `marker.id` so repeated hits each animate.
struct ShotFlash: View {
    let marker: ShotMarker?
    let imageSize: CGSize

    @State private var progress: CGFloat = 1   // 1 == finished / hidden

    private let maxRadius: CGFloat = 46
    private let baseRadius: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            if let marker, imageSize.width > 0 {
                let fit = AspectFit(image: imageSize, in: geo.size)
                let c = fit.map(marker.point)
                let radius = baseRadius + maxRadius * progress
                let alpha = Double(1 - progress)

                Circle()
                    .stroke(Color.yellow, lineWidth: 3)
                    .frame(width: radius * 2, height: radius * 2)
                    .position(c)
                    .opacity(alpha)

                Text("HIT")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .position(x: c.x, y: c.y - maxRadius - 12)
                    .opacity(alpha)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: marker?.id) { _, newId in
            guard newId != nil else { return }
            progress = 0
            withAnimation(.easeOut(duration: 0.45)) { progress = 1 }
        }
    }
}
