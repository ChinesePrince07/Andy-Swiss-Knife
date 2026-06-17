import CoreVideo
import Foundation

enum PixelBufferGray {
    /// Reads the luma (Y) plane of a bi-planar YUV buffer, subsampled by `downscale`.
    static func luma(from pixelBuffer: CVPixelBuffer, downscale: Int) -> (pixels: [UInt8], width: Int, height: Int)? {
        let step = max(1, downscale)
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 1,
              let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return nil }
        let srcW = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let srcH = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let src = base.assumingMemoryBound(to: UInt8.self)

        let dstW = srcW / step, dstH = srcH / step
        guard dstW > 0, dstH > 0 else { return nil }
        var out = [UInt8](repeating: 0, count: dstW * dstH)
        for y in 0..<dstH {
            let srcRow = (y * step) * rowBytes
            let dstRow = y * dstW
            for x in 0..<dstW {
                out[dstRow + x] = src[srcRow + x * step]
            }
        }
        return (out, dstW, dstH)
    }
}
