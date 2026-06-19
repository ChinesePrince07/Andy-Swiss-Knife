import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspect
        context.coordinator.start(previewLayer: v.videoPreviewLayer, session: session)
        return v
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    /// Rotates the preview by the SAME angle the detector buffers use
    /// (`...HorizonLevelCapture`, NOT `...Preview`). The overlay maps detector
    /// coordinates straight onto the preview, so the preview MUST show the exact
    /// pixel orientation of the buffer or the skeleton/shuttle land 90° off — which
    /// is precisely what happened in landscape, where the capture and preview
    /// horizon-level angles diverge (they agree in portrait, so it looked fine).
    final class Coordinator {
        private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
        private var observation: NSKeyValueObservation?

        func start(previewLayer: AVCaptureVideoPreviewLayer, session: AVCaptureSession) {
            guard let device = session.inputs.compactMap({ ($0 as? AVCaptureDeviceInput)?.device }).first else { return }
            let coord = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
            rotationCoordinator = coord
            Self.apply(coord.videoRotationAngleForHorizonLevelCapture, to: previewLayer)
            observation = coord.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak previewLayer] _, change in
                guard let previewLayer, let angle = change.newValue else { return }
                Self.apply(angle, to: previewLayer)
            }
        }

        private static func apply(_ angle: CGFloat, to layer: AVCaptureVideoPreviewLayer) {
            if let conn = layer.connection, conn.isVideoRotationAngleSupported(angle) {
                conn.videoRotationAngle = angle
            }
        }
    }
}
