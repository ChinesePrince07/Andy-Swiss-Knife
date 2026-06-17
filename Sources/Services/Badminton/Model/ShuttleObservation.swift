import CoreGraphics
import Foundation

/// A single detected shuttle position in image pixels (origin top-left).
struct ShuttleObservation {
    let point: CGPoint
    let confidence: Double   // 0...1
    let time: TimeInterval   // monotonic seconds
}
