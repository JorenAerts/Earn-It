import AVFoundation
import SwiftUI
import UIKit

/// Back-camera feed for missions that analyse frames themselves (the item scan).
/// Frames are delivered on a private serial queue, throttled to `interval`.
final class CameraFeed: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    /// `.unavailable` = the device has no usable camera. `.paused` = the camera exists but couldn't
    /// start right now (app not fully in the foreground yet, opened from the Lock Screen, another app
    /// using it, interruption) — callers retry instead of telling the user there's no camera.
    enum Status { case starting, running, denied, unavailable, paused }

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "be.gloop.camera")
    private var lastDelivery: CFTimeInterval = 0
    private var latest: CVPixelBuffer?
    private let lock = NSLock()

    var interval: CFTimeInterval = 0.25
    /// Called on the camera queue with throttled frames.
    var onFrame: (@Sendable (CVPixelBuffer) -> Void)?
    /// `true` when iOS interrupts the session, `false` when the interruption ends.
    var onInterruption: (@Sendable (Bool) -> Void)?

    override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) { [weak self] _ in
            self?.onInterruption?(true)
        }
        center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil) { [weak self] _ in
            self?.onInterruption?(false)
        }
        center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) { [weak self] _ in
            self?.onInterruption?(true)
        }
    }

    static var isAvailable: Bool { AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil }

    /// Asks for permission if needed, configures and starts the session.
    func start() async -> Status {
        guard Self.isAvailable else { return .unavailable }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { return .denied }
        default: return .denied
        }
        return await withCheckedContinuation { continuation in
            queue.async { [self] in
                if session.inputs.isEmpty { configure() }
                if !session.isRunning { session.startRunning() }
                continuation.resume(returning: session.isRunning ? .running : .paused)
            }
        }
    }

    func stop() {
        queue.async { [self] in if session.isRunning { session.stopRunning() } }
    }

    /// The most recent frame (for "take this shot" during setup).
    func latestFrame() -> CVPixelBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return latest
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lock.lock()
        latest = buffer
        lock.unlock()
        let now = CACurrentMediaTime()
        guard now - lastDelivery >= interval else { return }
        lastDelivery = now
        onFrame?(buffer)
    }
}

/// Live preview of a `CameraFeed`.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}
}
