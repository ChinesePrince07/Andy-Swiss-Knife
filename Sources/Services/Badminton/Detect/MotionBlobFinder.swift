import CoreGraphics
import Foundation

struct Blob: Equatable {
    let point: CGPoint
    let area: Int
    let peak: UInt8
}

enum MotionBlobFinder {
    /// Window (in pixels) around the peak used to compute the centroid + area.
    private static let windowRadius = 6

    static func brightestBlob(
        diff: [UInt8], width: Int, height: Int,
        threshold: UInt8, minArea: Int, maxArea: Int,
        near: CGPoint?, searchRadius: Double
    ) -> Blob? {
        guard diff.count == width * height, width > 0, height > 0 else { return nil }

        // 1) Find the brightest qualifying pixel (optionally near a prior point).
        var peakVal: UInt8 = 0
        var peakX = -1, peakY = -1
        for y in 0..<height {
            let row = y * width
            for x in 0..<width {
                let v = diff[row + x]
                if v < threshold { continue }
                if let n = near {
                    let dx = Double(x) - n.x, dy = Double(y) - n.y
                    if (dx * dx + dy * dy) > searchRadius * searchRadius { continue }
                }
                if v > peakVal { peakVal = v; peakX = x; peakY = y }
            }
        }
        guard peakX >= 0 else { return nil }

        // 2) Intensity-weighted centroid + bright-pixel area in a window around the peak.
        var sumW = 0.0, sumX = 0.0, sumY = 0.0, area = 0
        let x0 = max(0, peakX - windowRadius), x1 = min(width - 1, peakX + windowRadius)
        let y0 = max(0, peakY - windowRadius), y1 = min(height - 1, peakY + windowRadius)
        for y in y0...y1 {
            let row = y * width
            for x in x0...x1 {
                let v = diff[row + x]
                if v < threshold { continue }
                let w = Double(v)
                sumW += w; sumX += w * Double(x); sumY += w * Double(y); area += 1
            }
        }
        guard sumW > 0, area >= minArea, area <= maxArea else { return nil }
        return Blob(point: CGPoint(x: sumX / sumW, y: sumY / sumW), area: area, peak: peakVal)
    }
}
