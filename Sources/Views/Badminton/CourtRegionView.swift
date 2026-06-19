import SwiftUI
import AVFoundation

/// Tap two opposite corners to mark the court playing area. Shuttle detections
/// outside it are dropped — this rejects the background clutter (ad banners, crowd,
/// off-court reflections, or — when testing against a screen — everything around
/// the monitor) that the detector otherwise latches onto.
struct CourtRegionView: View {
    let session: AVCaptureSession
    let imageSize: CGSize
    let onDone: (CGRect?) -> Void   // normalized 0...1 rect, or nil to clear
    let onCancel: () -> Void

    @State private var points: [CGPoint] = []   // display coords

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
                        ctx.stroke(Path(box(points[0], points[1])), with: .color(AppColors.accent), lineWidth: 3)
                    }
                }
                .ignoresSafeArea()
                VStack {
                    Text("TAP TWO OPPOSITE CORNERS OF THE COURT")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 5).background(Color.black.opacity(0.6))
                    Spacer()
                    HStack {
                        Button("CANCEL") { onCancel() }
                        Spacer()
                        Button("CLEAR") { onDone(nil) }
                        Spacer()
                        Button("RESET") { points.removeAll() }
                        Spacer()
                        Button("CONFIRM") { confirm(displaySize: geo.size) }.disabled(points.count != 2)
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

    private func box(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    /// Convert the two display-space taps to a normalized image rect (inverse aspect-fit).
    private func confirm(displaySize: CGSize) {
        guard points.count == 2, imageSize.width > 0, imageSize.height > 0 else { return }
        let scaleF = min(displaySize.width / imageSize.width, displaySize.height / imageSize.height)
        let offX = (displaySize.width - imageSize.width * scaleF) / 2
        let offY = (displaySize.height - imageSize.height * scaleF) / 2
        func norm(_ p: CGPoint) -> CGPoint {
            CGPoint(x: ((p.x - offX) / scaleF) / imageSize.width,
                    y: ((p.y - offY) / scaleF) / imageSize.height)
        }
        let r = box(norm(points[0]), norm(points[1]))
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))   // clamp into frame
        guard r.width > 0.05, r.height > 0.05 else { return }        // ignore tiny boxes
        onDone(r)
    }
}
