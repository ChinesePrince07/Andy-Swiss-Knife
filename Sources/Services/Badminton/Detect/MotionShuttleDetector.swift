import CoreVideo
import CoreGraphics
import Foundation

/// Classical frame-difference shuttle detector. Works for a single fast object
/// against a calm-ish background; replaced by a TrackNetV3 Core ML detector later.
final class MotionShuttleDetector: ShuttleDetector {
    private let downscale: Int
    private let threshold: UInt8
    private let minArea: Int
    private let maxArea: Int
    private let minConfidence: Double

    private var prev: [UInt8]?
    private var prevW = 0
    private var prevH = 0
    private var lastPointDown: CGPoint?

    init(downscale: Int = 2, threshold: UInt8 = 28, minArea: Int = 2, maxArea: Int = 120,
         minConfidence: Double = 0.35) {
        self.downscale = downscale
        self.threshold = threshold
        self.minArea = minArea
        self.maxArea = maxArea
        self.minConfidence = minConfidence
    }

    func detect(pixelBuffer: CVPixelBuffer, time: TimeInterval) -> ShuttleObservation? {
        guard let gray = PixelBufferGray.luma(from: pixelBuffer, downscale: downscale) else { return nil }
        defer { prev = gray.pixels; prevW = gray.width; prevH = gray.height }
        guard let p = prev, gray.width == prevW, gray.height == prevH else { return nil }

        var diff = [UInt8](repeating: 0, count: gray.pixels.count)
        for i in 0..<gray.pixels.count {
            let d = Int(gray.pixels[i]) - Int(p[i])
            diff[i] = UInt8(min(255, abs(d)))
        }

        let near = lastPointDown
        let searchRadius = near == nil ? .greatestFiniteMagnitude : Double(max(gray.width, gray.height)) * 0.4
        guard let blob = MotionBlobFinder.brightestBlob(
            diff: diff, width: gray.width, height: gray.height,
            threshold: threshold, minArea: minArea, maxArea: maxArea,
            near: near, searchRadius: searchRadius) else {
            lastPointDown = nil
            return nil
        }

        // Reject faint blobs (sensor/lighting noise): a real moving object
        // produces a strong frame difference, noise barely clears the threshold.
        let confidence = min(1.0, Double(blob.peak) / 255.0)
        guard confidence >= minConfidence else {
            lastPointDown = nil
            return nil
        }
        lastPointDown = blob.point

        // Map downscaled coords back to full-resolution image pixels.
        let full = CGPoint(x: blob.point.x * Double(downscale), y: blob.point.y * Double(downscale))
        return ShuttleObservation(point: full, confidence: confidence, time: time)
    }
}
