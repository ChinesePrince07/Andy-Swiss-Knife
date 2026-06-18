import Vision
import CoreML
import CoreVideo
import CoreGraphics
import Foundation

protocol PoseDetector: AnyObject {
    /// Detect players, returning poses in FULL-resolution image pixels.
    func detect(pixelBuffer: CVPixelBuffer) -> [PlayerPose]
}

/// Player pose detector backed by YOLO11-pose (Core ML, via Vision).
/// Used only on the camera's serial delivery queue.
final class YOLOPoseDetector: PoseDetector {
    static let inputSize: Float = 640

    private let vnModel: VNCoreMLModel
    private let confThreshold: Float

    init?(confThreshold: Float = 0.4) {
        guard let url = Bundle.main.url(forResource: "YOLO11Pose", withExtension: "mlmodelc") else { return nil }
        let config = MLModelConfiguration()
        config.computeUnits = .all
        guard let model = try? MLModel(contentsOf: url, configuration: config),
              let vn = try? VNCoreMLModel(for: model) else { return nil }
        self.vnModel = vn
        self.confThreshold = confThreshold
    }

    func detect(pixelBuffer: CVPixelBuffer) -> [PlayerPose] {
        let fullW = CVPixelBufferGetWidth(pixelBuffer)
        let fullH = CVPixelBufferGetHeight(pixelBuffer)
        guard fullW > 0, fullH > 0 else { return [] }

        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .scaleFill   // stretch to 640x640 -> simple inverse scale
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        guard (try? handler.perform([request])) != nil,
              let obs = request.results?.first as? VNCoreMLFeatureValueObservation,
              let arr = obs.featureValue.multiArrayValue else { return [] }

        let numAnchors = arr.shape.count >= 3 ? arr.shape[2].intValue : (arr.count / YOLOPoseDecoder.channels)
        let raw = Self.toFloatArray(arr)
        let normalized = YOLOPoseDecoder.decode(raw: raw, numAnchors: numAnchors,
                                                inputSize: Self.inputSize, confThreshold: confThreshold)

        // Normalized [0,1] -> full-resolution image pixels (scaleFill was a stretch).
        let w = Double(fullW), h = Double(fullH)
        return normalized.map { pose in
            PlayerPose(
                box: CGRect(x: pose.box.minX * w, y: pose.box.minY * h,
                            width: pose.box.width * w, height: pose.box.height * h),
                score: pose.score,
                keypoints: pose.keypoints.map {
                    PoseKeypoint(point: CGPoint(x: $0.point.x * w, y: $0.point.y * h), confidence: $0.confidence)
                }
            )
        }
    }

    private static func toFloatArray(_ m: MLMultiArray) -> [Float] {
        let n = m.count
        var out = [Float](repeating: 0, count: n)
        switch m.dataType {
        case .float32:
            let p = m.dataPointer.bindMemory(to: Float.self, capacity: n)
            for i in 0..<n { out[i] = p[i] }
        case .float16:
            let p = m.dataPointer.bindMemory(to: Float16.self, capacity: n)
            for i in 0..<n { out[i] = Float(p[i]) }
        case .double:
            let p = m.dataPointer.bindMemory(to: Double.self, capacity: n)
            for i in 0..<n { out[i] = Float(p[i]) }
        @unknown default:
            return []
        }
        return out
    }
}
