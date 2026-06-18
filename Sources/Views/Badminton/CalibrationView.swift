import SwiftUI
import AVFoundation

/// Tap the two endpoints of a known real-world length (default: the net posts,
/// 1.55 m apart) to derive the pixels↔metres scale used for speed.
struct CalibrationView: View {
    let session: AVCaptureSession
    let imageSize: CGSize
    let realMeters: Double            // default 1.55 (net height)
    let onDone: (ReferenceScale) -> Void
    let onCancel: () -> Void

    @State private var points: [CGPoint] = []   // in display coords

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CameraPreview(session: session).ignoresSafeArea()
                Canvas { ctx, _ in
                    for p in points {
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)),
                                 with: .color(AppColors.accent))
                    }
                    if points.count == 2 {
                        var path = Path(); path.move(to: points[0]); path.addLine(to: points[1])
                        ctx.stroke(path, with: .color(AppColors.accent), lineWidth: 3)
                    }
                }
                .ignoresSafeArea()
                VStack {
                    Text("TAP THE TOP OF EACH NET POST (1.55 m)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 5).background(Color.black.opacity(0.6))
                    Spacer()
                    HStack {
                        Button("CANCEL") { onCancel() }
                        Spacer()
                        Button("RESET") { points.removeAll() }
                        Spacer()
                        Button("CONFIRM") { confirm(displaySize: geo.size) }
                            .disabled(points.count != 2)
                    }
                    .font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 8).background(Color.black.opacity(0.6))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { loc in
                if points.count >= 2 { points.removeAll() }
                points.append(loc)
            }
        }
    }

    /// Convert the two display-space taps to image pixels (inverse of the aspect-fit map).
    private func confirm(displaySize: CGSize) {
        guard points.count == 2, imageSize.width > 0 else { return }
        let scaleF = min(displaySize.width / imageSize.width, displaySize.height / imageSize.height)
        let offX = (displaySize.width - imageSize.width * scaleF) / 2
        let offY = (displaySize.height - imageSize.height * scaleF) / 2
        func toImage(_ p: CGPoint) -> CGPoint {
            CGPoint(x: (p.x - offX) / scaleF, y: (p.y - offY) / scaleF)
        }
        guard let s = ReferenceScale(p1: toImage(points[0]), p2: toImage(points[1]), realMeters: realMeters) else { return }
        onDone(s)
    }
}
