import CoreGraphics
import Foundation

/// Decodes a TrackNet heatmap plane (row-major, `width*height` values in 0...1)
/// into a sub-pixel shuttle position: the intensity-weighted centroid around the
/// peak, or nil if the peak is below `threshold` (no confident detection).
enum HeatmapDecoder {
    static func locate(heatmap: [Float], width: Int, height: Int,
                       threshold: Float, window: Int = 3) -> (point: CGPoint, peak: Float)? {
        guard heatmap.count == width * height, width > 0, height > 0 else { return nil }

        var peak: Float = 0
        var peakIdx = -1
        for i in 0..<heatmap.count where heatmap[i] > peak {
            peak = heatmap[i]; peakIdx = i
        }
        guard peakIdx >= 0, peak >= threshold else { return nil }

        let px = peakIdx % width, py = peakIdx / width
        // Intensity-weighted centroid in a window around the peak (sub-pixel).
        let cutoff = threshold * 0.5
        var sumW: Float = 0, sumX: Float = 0, sumY: Float = 0
        for dy in -window...window {
            let y = py + dy
            if y < 0 || y >= height { continue }
            for dx in -window...window {
                let x = px + dx
                if x < 0 || x >= width { continue }
                let v = heatmap[y * width + x]
                if v < cutoff { continue }
                sumW += v; sumX += v * Float(x); sumY += v * Float(y)
            }
        }
        guard sumW > 0 else { return (CGPoint(x: Double(px), y: Double(py)), peak) }
        return (CGPoint(x: Double(sumX / sumW), y: Double(sumY / sumW)), peak)
    }
}
