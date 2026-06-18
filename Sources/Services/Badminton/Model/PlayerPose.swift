import CoreGraphics
import Foundation

/// One body keypoint (COCO-17), in the same coordinate space as its `PlayerPose`.
struct PoseKeypoint: Sendable {
    let point: CGPoint
    let confidence: Float
}

/// A detected player: bounding box + 17 COCO keypoints.
struct PlayerPose: Sendable {
    let box: CGRect
    let score: Float
    let keypoints: [PoseKeypoint]   // 17, COCO order

    /// COCO-17 keypoint indices.
    enum Joint: Int {
        case nose, leftEye, rightEye, leftEar, rightEar,
             leftShoulder, rightShoulder, leftElbow, rightElbow,
             leftWrist, rightWrist, leftHip, rightHip,
             leftKnee, rightKnee, leftAnkle, rightAnkle
    }

    /// Skeleton edges (pairs of COCO-17 indices) for drawing the stick figure.
    static let skeleton: [(Int, Int)] = [
        (5, 6), (5, 7), (7, 9), (6, 8), (8, 10),     // shoulders + arms
        (5, 11), (6, 12), (11, 12),                  // torso
        (11, 13), (13, 15), (12, 14), (14, 16),      // legs
        (0, 1), (0, 2), (1, 3), (2, 4), (0, 5), (0, 6) // head + neck
    ]
}
