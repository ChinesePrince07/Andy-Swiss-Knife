// Sources/Services/Badminton/Capture/CameraSession.swift
import AVFoundation
import CoreVideo
import Foundation

// @unchecked Sendable: all mutable AV state (session/output config, start/stop)
// is confined to the private serial `queue`; `onFrame` is set once before
// `start()`. Lets the @MainActor engine call `configure/start/stop` without the
// compiler flagging the cross-isolation send of this non-Sendable wrapper.
final class CameraSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    /// Set once before `start()`. `@Sendable` because it is invoked from the
    /// capture delivery queue; the engine assigns a closure that only captures a
    /// Sendable processor + weak (main-actor) self.
    var onFrame: (@Sendable (CVPixelBuffer, TimeInterval) -> Void)?

    private let queue = DispatchQueue(label: "badminton.camera.frames")
    private let output = AVCaptureVideoDataOutput()

    /// Requests access + configures a 1080p video-data output at `fps`. Returns success.
    func configure(fps: Int) async -> Bool {
        let granted = await Self.requestAccess()
        guard granted else { return false }
        return await withCheckedContinuation { cont in
            queue.async {
                cont.resume(returning: self.configureLocked(fps: fps))
            }
        }
    }

    private static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    private func configureLocked(fps: Int) -> Bool {
        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration(); return false
        }
        session.addInput(input)

        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { session.commitConfiguration(); return false }
        session.addOutput(output)
        // Deliver portrait-up buffers so the detectors see the scene the same way
        // the (auto-rotated) preview shows it. Without this the models get the raw
        // landscape sensor buffer — people appear sideways and aren't detected.
        if let conn = output.connection(with: .video), conn.isVideoRotationAngleSupported(90) {
            conn.videoRotationAngle = 90
        }
        session.commitConfiguration()

        // Best-effort frame-rate lock.
        if let format = bestFormat(for: device, fps: fps), (try? device.lockForConfiguration()) != nil {
            device.activeFormat = format
            let duration = CMTime(value: 1, timescale: CMTimeScale(fps))
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            device.unlockForConfiguration()
        }
        return true
    }

    private func bestFormat(for device: AVCaptureDevice, fps: Int) -> AVCaptureDevice.Format? {
        device.formats.first { f in
            let d = CMVideoFormatDescriptionGetDimensions(f.formatDescription)
            let supportsFps = f.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= Double(fps) }
            return d.width == 1920 && d.height == 1080 && supportsFps
        }
    }

    func start() { queue.async { if !self.session.isRunning { self.session.startRunning() } } }
    func stop() { queue.async { if self.session.isRunning { self.session.stopRunning() } } }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let t = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        onFrame?(buffer, t)
    }
}
