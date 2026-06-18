import CoreGraphics

/// Maps a point from image space into an aspect-fit view (the camera preview is
/// `.scaledToFit`-style centered). Shared by the overlay and the hit flash so the
/// scale/offset math lives in one place.
struct AspectFit {
    let scale: CGFloat
    let offset: CGPoint

    init(image: CGSize, in view: CGSize) {
        if image.width > 0, image.height > 0 {
            scale = min(view.width / image.width, view.height / image.height)
        } else {
            scale = 1
        }
        offset = CGPoint(x: (view.width - image.width * scale) / 2,
                         y: (view.height - image.height * scale) / 2)
    }

    func map(_ p: CGPoint) -> CGPoint {
        CGPoint(x: offset.x + p.x * scale, y: offset.y + p.y * scale)
    }

    func map(_ r: CGRect) -> CGRect {
        CGRect(x: offset.x + r.minX * scale, y: offset.y + r.minY * scale,
               width: r.width * scale, height: r.height * scale)
    }
}
