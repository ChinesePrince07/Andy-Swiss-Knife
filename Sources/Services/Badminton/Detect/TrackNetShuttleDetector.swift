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
/// median), runs the model each frame, and decodes a 3-window temporal ensemble
/// of a middle frame.
///
/// Why a middle frame and not the newest: TrackNet predicts each frame from the
/// 8-frame temporal window, and the prediction for a frame at the *edge* of that
/// window (e.g. the newest, with no future context) is its least reliable — the
/// reference temporal ensemble weights edge frames 1/20 vs 4/20 for the middle.
/// Offline study on real footage (1280x720 match video) showed decoding the newest
/// frame (ch7) gave a p90 frame-to-frame jump of ~203px (the "bouncing" noise),
/// while decoding the middle (ch4) cut that ~10x to ~22px with the same background.
///
/// Why an ensemble: the SAME frame is predicted by 3 overlapping windows (it sits
/// at channel 3 of the current window, 4 of the previous, 5 of the one before).
/// Averaging those three heatmaps corroborates the true shuttle and cancels
/// per-window noise, which lets the confidence threshold drop to 0.25 for ~2-4x
/// more detections while staying clean — even on harder segments where the single
/// middle channel fell apart (p90 ~83px). Cost: the detection lags the live frame
/// by 4 frames (~67ms at 60fps), so the observation is timestamped with that
/// frame's time to keep velocities correct.
///
/// Used only on the camera's serial delivery queue (single-threaded access).
final class TrackNetShuttleDetector: ShuttleDetector {
    static let inW = 512
    static let inH = 288
    static let seqLen = 8
    static let inDim = 27          // 3 (bg) + 8*3 (frames)
    static let outChannels = 8
    static let ensembleTimeIndex = 3   // the ensembled frame's index in frames[]/times[] (= ch3 of this window)

    private let model: MLModel
    private let ciContext: CIContext
    private let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    private let threshold: Float
    private let bgAlpha: Float

    private var frames: [[Float]] = []   // each: planar RGB [3*plane], normalized 0...1
    private var times: [TimeInterval] = []   // timestamp of each buffered frame (aligned to `frames`)
    private var bg: [Float]?             // EMA background, planar RGB [3*plane]
    private var midHistory: [(c3: [Float], c4: [Float], c5: [Float])] = []  // last ≤3 windows' middle channels
    private let input: MLMultiArray      // reused [1,27,288,512] float32

    private var plane: Int { Self.inW * Self.inH }

    /// Fails if the bundled compiled model can't be loaded.
    init?(threshold: Float = 0.25, bgAlpha: Float = 0.02) {
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
        times.append(time)
        if frames.count > Self.seqLen { frames.removeFirst(); times.removeFirst() }
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

        // Temporal ensemble (see class doc): the frame at `ensembleTimeIndex` is
        // predicted by 3 overlapping windows — channel 3 of THIS window, 4 of the
        // previous, 5 of the one before. Averaging corroborates the real shuttle
        // and cancels per-window noise. Report that frame's timestamp (it lags the
        // live frame by 4 frames) so velocities stay correct.
        guard let c3 = extractPlane(heat, channel: 3),
              let c4 = extractPlane(heat, channel: 4),
              let c5 = extractPlane(heat, channel: 5) else { return nil }
        midHistory.append((c3: c3, c4: c4, c5: c5))
        if midHistory.count > 3 { midHistory.removeFirst() }
        guard midHistory.count == 3 else { return nil }   // ensemble warming up

        let cur = midHistory[2].c3, prv = midHistory[1].c4, prv2 = midHistory[0].c5
        var avg = [Float](repeating: 0, count: p)
        for i in 0..<p { avg[i] = (cur[i] + prv[i] + prv2[i]) / 3 }
        guard let r = HeatmapDecoder.locate(heatmap: avg, width: Self.inW, height: Self.inH, threshold: threshold) else { return nil }

        // Scale 512x288 -> full-resolution image pixels (the resize was a stretch).
        let full = CGPoint(x: r.point.x * Double(fullW) / Double(Self.inW),
                           y: r.point.y * Double(fullH) / Double(Self.inH))
        return ShuttleObservation(point: full, confidence: Double(r.peak), time: times[Self.ensembleTimeIndex])
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
