import CoreGraphics
import Foundation

struct ReferenceScale: Equatable, Codable {
    let metersPerPixel: Double

    init?(p1: CGPoint, p2: CGPoint, realMeters: Double) {
        guard realMeters > 0 else { return nil }
        let dx = p2.x - p1.x, dy = p2.y - p1.y
        let pixels = (dx * dx + dy * dy).squareRoot()
        guard pixels > 0 else { return nil }
        self.metersPerPixel = realMeters / pixels
    }

    func meters(pixels: Double) -> Double { pixels * metersPerPixel }

    func meters(from a: CGPoint, to b: CGPoint) -> Double {
        let dx = b.x - a.x, dy = b.y - a.y
        return (dx * dx + dy * dy).squareRoot() * metersPerPixel
    }
}
