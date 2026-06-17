import CoreGraphics
import Foundation

struct Blob: Equatable {
    let point: CGPoint
    let area: Int
    let peak: UInt8
}

enum MotionBlobFinder {
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

        // 2) Flood-fill the connected bright region containing the peak (4-neighbour),
        //    accumulating an intensity-weighted centroid + true pixel area. Measuring the
        //    whole connected component (not a fixed window) is what lets `maxArea` reject
        //    large moving objects like a player's body while keeping the small shuttle.
        var visited = [Bool](repeating: false, count: width * height)
        var stack: [(Int, Int)] = [(peakX, peakY)]
        visited[peakY * width + peakX] = true
        var sumW = 0.0, sumX = 0.0, sumY = 0.0, area = 0
        while let (x, y) = stack.popLast() {
            let v = diff[y * width + x]
            let w = Double(v)
            sumW += w; sumX += w * Double(x); sumY += w * Double(y); area += 1
            if area > maxArea { return nil }   // region already too big -> reject early
            let neighbours = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
            for (nx, ny) in neighbours where nx >= 0 && nx < width && ny >= 0 && ny < height {
                let idx = ny * width + nx
                if visited[idx] || diff[idx] < threshold { continue }
                visited[idx] = true
                stack.append((nx, ny))
            }
        }
        guard sumW > 0, area >= minArea, area <= maxArea else { return nil }
        return Blob(point: CGPoint(x: sumX / sumW, y: sumY / sumW), area: area, peak: peakVal)
    }
}
