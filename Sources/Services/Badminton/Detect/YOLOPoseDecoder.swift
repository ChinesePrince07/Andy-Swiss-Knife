import CoreGraphics
import Foundation

/// Decodes raw YOLO11-pose output into player poses (normalized 0...1 coords).
///
/// Raw output is `[56, numAnchors]` channel-major: per anchor a,
/// `[cx, cy, w, h, conf, (kx,ky,kv) * 17]` in input pixels. We confidence-filter,
/// build boxes/keypoints (normalized by `inputSize`), and run NMS.
enum YOLOPoseDecoder {
    static let numKeypoints = 17
    static let channels = 56        // 4 box + 1 conf + 17*3

    static func decode(raw: [Float], numAnchors: Int, inputSize: Float,
                       confThreshold: Float = 0.4, iouThreshold: Float = 0.45,
                       maxPlayers: Int = 4) -> [PlayerPose] {
        guard inputSize > 0, numAnchors > 0, raw.count == channels * numAnchors else { return [] }
        func ch(_ c: Int, _ a: Int) -> Float { raw[c * numAnchors + a] }

        var candidates: [PlayerPose] = []
        for a in 0..<numAnchors {
            let conf = ch(4, a)
            if conf < confThreshold { continue }
            let cx = ch(0, a) / inputSize, cy = ch(1, a) / inputSize
            let w = ch(2, a) / inputSize, h = ch(3, a) / inputSize
            let box = CGRect(x: Double(cx - w / 2), y: Double(cy - h / 2),
                             width: Double(w), height: Double(h))
            var kpts: [PoseKeypoint] = []
            kpts.reserveCapacity(numKeypoints)
            for k in 0..<numKeypoints {
                let kx = ch(5 + 3 * k, a) / inputSize
                let ky = ch(5 + 3 * k + 1, a) / inputSize
                let kv = ch(5 + 3 * k + 2, a)
                kpts.append(PoseKeypoint(point: CGPoint(x: Double(kx), y: Double(ky)), confidence: kv))
            }
            candidates.append(PlayerPose(box: box, score: conf, keypoints: kpts))
        }

        // Greedy NMS by box IoU.
        candidates.sort { $0.score > $1.score }
        var kept: [PlayerPose] = []
        var suppressed = [Bool](repeating: false, count: candidates.count)
        for i in 0..<candidates.count {
            if suppressed[i] { continue }
            kept.append(candidates[i])
            if kept.count >= maxPlayers { break }
            for j in (i + 1)..<candidates.count where !suppressed[j] {
                if iou(candidates[i].box, candidates[j].box) > iouThreshold { suppressed[j] = true }
            }
        }
        return kept
    }

    static func iou(_ a: CGRect, _ b: CGRect) -> Float {
        let inter = a.intersection(b)
        if inter.isNull || inter.isEmpty { return 0 }
        let interArea = Float(inter.width * inter.height)
        let union = Float(a.width * a.height + b.width * b.height) - interArea
        return union > 0 ? interArea / union : 0
    }
}
