import CoreVideo
import Foundation

protocol ShuttleDetector: AnyObject {
    /// Returns a shuttle observation in FULL-resolution image pixels, or nil.
    func detect(pixelBuffer: CVPixelBuffer, time: TimeInterval) -> ShuttleObservation?
}
