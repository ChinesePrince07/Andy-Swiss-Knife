import CoreML
import CoreVideo
import CoreImage
import CoreGraphics
import Foundation

/// On-device shuttle detector backed by the converted TrackNetV3 tracking module.
///
/// The model wants `frames[1,27,288,512] = [median_bg(3), 8 RGB frames(24)]`, each
/// channel resized to 512x288 and divided by 255; it returns `heatmaps[1,8,288,512]`
/// (one sigmoid heatmap per input frame). This detector keeps an 8-frame ring
/// buffer + an EMA background estimate (a live stand-in for the training-time
/// median), runs the model each frame, and decodes the NEWEST frame's heatmap.
///
/// Used only on the camera's serial delivery queue (single-threaded access).
final class TrackNetShuttleDetector: ShuttleDetector {
    static let inW = 512
    static let inH = 288
    static let seqLen = 8
    static let inDim = 27          // 3 (bg) + 8*3 (frames)
    static let outChannels = 8

    private let model: MLModel
    private let ciContext: CIContext
    private let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    private let threshold: Float
    private let bgAlpha: Float

    private var frames: [[Float]] = []   // each: planar RGB [3*plane], normalized 0...1
    private var bg: [Float]?             // EMA background, planar RGB [3*plane]
    private let input: MLMultiArray      // reused [1,27,288,512] float32

    private var plane: Int { Self.inW * Self.inH }

    /// Fails if the bundled compiled model can't be loaded.
    init?(threshold: Float = 0.5, bgAlpha: Float = 0.02) {
        guard let url = Bundle.main.url(forResource: "TrackNet", withExtension: "mlmodelc") else { return nil }
        let config = MLModelConfiguration()
        config.computeUnits = .all   // Neural Engine + GPU + CPU
        guard let m = try? MLModel(contentsOf: url, configuration: config),
              let arr = try? MLMultiArray(
                shape: [1, NSNumber(value: Self.inDim), NSNumber(value: Self.inH), NSNumber(value: Self.inW)],
                dataType: .float32) else { return nil }
        self.model = m
        self.input = arr
        self.threshold = threshold
        self.bgAlpha = bgAlpha
        self.ciContext = CIContext(options: [.useSoftwareRenderer: false])
    }

    func detect(pixelBuffer: CVPixelBuffer, time: TimeInterval) -> ShuttleObservation? {
        let fullW = CVPixelBufferGetWidth(pixelBuffer)
        let fullH = CVPixelBufferGetHeight(pixelBuffer)
        guard fullW > 0, fullH > 0, let rgb = renderRGBPlanar(pixelBuffer) else { return nil }

        // EMA background (live stand-in for the training median).
        if var b = bg {
            let a = bgAlpha
            for i in 0..<b.count { b[i] = b[i] * (1 - a) + rgb[i] * a }
            bg = b
        } else {
            bg = rgb
        }

        frames.append(rgb)
        if frames.count > Self.seqLen { frames.removeFirst() }
        guard frames.count == Self.seqLen, let bg = bg else { return nil }   // warming up

        // Pack [bg(3), frame0..7(24)] into the reused input via fast plane copies.
        let p = plane
        let dst = input.dataPointer.bindMemory(to: Float.self, capacity: Self.inDim * p)
        bg.withUnsafeBufferPointer { src in dst.update(from: src.baseAddress!, count: 3 * p) }
        for f in 0..<Self.seqLen {
            frames[f].withUnsafeBufferPointer { src in
                (dst + (3 + f * 3) * p).update(from: src.baseAddress!, count: 3 * p)
            }
        }

        guard let provider = try? MLDictionaryFeatureProvider(dictionary: ["frames": input]),
              let out = try? model.prediction(from: provider),
              let heat = out.featureValue(for: "heatmaps")?.multiArrayValue else { return nil }

        // Newest frame's heatmap = channel (seqLen-1).
        guard let hm = extractPlane(heat, channel: Self.seqLen - 1) else { return nil }
        guard let r = HeatmapDecoder.locate(heatmap: hm, width: Self.inW, height: Self.inH, threshold: threshold) else { return nil }

        // Scale 512x288 -> full-resolution image pixels (the resize was a stretch).
        let full = CGPoint(x: r.point.x * Double(fullW) / Double(Self.inW),
                           y: r.point.y * Double(fullH) / Double(Self.inH))
        return ShuttleObservation(point: full, confidence: Double(r.peak), time: time)
    }

    /// CoreImage: pixel buffer (any format) -> 512x288 planar RGB, normalized 0...1.
    private func renderRGBPlanar(_ pb: CVPixelBuffer) -> [Float]? {
        let ci = CIImage(cvPixelBuffer: pb)
        guard ci.extent.width > 0, ci.extent.height > 0 else { return nil }
        let sx = CGFloat(Self.inW) / ci.extent.width
        let sy = CGFloat(Self.inH) / ci.extent.height
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
        let rect = CGRect(x: 0, y: 0, width: Self.inW, height: Self.inH)

        var rgba = [UInt8](repeating: 0, count: Self.inW * Self.inH * 4)
        rgba.withUnsafeMutableBytes { buf in
            ciContext.render(scaled, toBitmap: buf.baseAddress!, rowBytes: Self.inW * 4,
                             bounds: rect, format: .RGBA8, colorSpace: rgbColorSpace)
        }

        let p = plane
        var out = [Float](repeating: 0, count: 3 * p)
        for i in 0..<p {
            out[i]         = Float(rgba[i * 4 + 0]) / 255   // R plane
            out[p + i]     = Float(rgba[i * 4 + 1]) / 255   // G plane
            out[2 * p + i] = Float(rgba[i * 4 + 2]) / 255   // B plane
        }
        return out
    }

    /// Extract one heatmap channel as [Float], handling float16/float32 output.
    private func extractPlane(_ m: MLMultiArray, channel: Int) -> [Float]? {
        let p = plane
        let base = channel * p
        var out = [Float](repeating: 0, count: p)
        switch m.dataType {
        case .float32:
            let ptr = m.dataPointer.bindMemory(to: Float.self, capacity: Self.outChannels * p)
            for i in 0..<p { out[i] = ptr[base + i] }
        case .float16:
            let ptr = m.dataPointer.bindMemory(to: Float16.self, capacity: Self.outChannels * p)
            for i in 0..<p { out[i] = Float(ptr[base + i]) }
        default:
            return nil
        }
        return out
    }
}
