import AVFoundation
import ImageIO
import SwiftUI
import UIKit

/// Back-camera feed for the camera missions. Frames are delivered on a private serial queue,
/// throttled to `interval`. Also: flashlight control, scene brightness (for auto flashlight) and,
/// when `codeTypes` is set before `start()`, QR/barcode payloads.
final class CameraFeed: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate,
                        @unchecked Sendable {
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
    /// Scene brightness (EXIF BrightnessValue, roughly −5 pitch dark … 10 sunlight), about twice a second.
    var onBrightness: (@Sendable (Double) -> Void)?
    /// Codes to recognise (set before `start()`); payloads go to `onCodes` on the camera queue.
    var codeTypes: [AVMetadataObject.ObjectType] = []
    var onCodes: (@Sendable ([String]) -> Void)?

    /// Only touched on `queue`.
    private var device: AVCaptureDevice?
    private var lastBrightness: CFTimeInterval = 0

    /// Whether this camera has a usable flashlight (no: iPad, Simulator).
    static var hasTorch: Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return false }
        return device.hasTorch
    }

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
        queue.async { [self] in
            applyTorch(false)
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Flashlight on/off. Ignored when the camera isn't running or has no torch.
    func setTorch(_ on: Bool) {
        queue.async { [self] in applyTorch(on) }
    }

    private func applyTorch(_ on: Bool) {
        guard let device, device.hasTorch, session.isRunning || !on else { return }
        guard (device.torchMode == .on) != on, (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }
        if on, device.isTorchAvailable {
            try? device.setTorchModeOn(level: 0.6)  // bright enough, less glare and heat than full power
        } else {
            device.torchMode = .off
        }
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
            self.device = device
            // Codes are often scanned up close: let the lens focus near.
            if !codeTypes.isEmpty, device.isAutoFocusRangeRestrictionSupported, (try? device.lockForConfiguration()) != nil {
                device.autoFocusRangeRestriction = .near
                device.unlockForConfiguration()
            }
        }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        if !codeTypes.isEmpty {
            let metadata = AVCaptureMetadataOutput()
            if session.canAddOutput(metadata) {
                session.addOutput(metadata)
                metadata.setMetadataObjectsDelegate(self, queue: queue)
                metadata.metadataObjectTypes = codeTypes.filter(metadata.availableMetadataObjectTypes.contains)
            }
        }
        session.commitConfiguration()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        let payloads = metadataObjects.compactMap { ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }
        if !payloads.isEmpty { onCodes?(payloads) }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let now = CACurrentMediaTime()
        if let onBrightness, now - lastBrightness >= 0.5,
           let attachments = CMCopyDictionaryOfAttachments(allocator: nil, target: sampleBuffer,
                                                           attachmentMode: kCMAttachmentMode_ShouldPropagate) as? [String: Any],
           let value = CameraBrightness.value(fromAttachments: attachments) {
            lastBrightness = now
            onBrightness(value)
        }
        lock.lock()
        latest = buffer
        lock.unlock()
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
