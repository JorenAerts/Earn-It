@preconcurrency import AVFoundation
import Buddies
import Permissions
import SwiftUI
import Telemetry
import UIKit

/// After the mission: snap a front-camera selfie (one retake), pick clubs, post — or skip.
/// Either way the others' photos of today unlock.
struct ShareMorningView: View {
    @Environment(BuddiesModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var camera = SelfieCamera()
    @State private var photo: UIImage?
    @State private var retakesLeft = 1
    @State private var selected: Set<UUID> = []
    @State private var busy = false
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(Color.black)
                    if let photo {
                        Image(uiImage: photo).resizable().scaledToFill()
                    } else if camera.status == .running {
                        CameraLayerView(session: camera.session)
                    } else if camera.status == .denied || camera.status == .unavailable {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.fill").font(.largeTitle)
                            Text(camera.status == .denied ? "Camera is off for Gloop." : "No front camera available.")
                            if camera.status == .denied {
                                Button("Open Settings") { PermissionCenter.shared.openSettings(.camera) }
                                    .buttonStyle(.bordered)
                            }
                        }
                        .foregroundStyle(.white)
                    } else {
                        ProgressView().tint(.white)
                    }
                }
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 24))
                .frame(maxWidth: 420)

                if photo == nil {
                    Button(action: snap) {
                        Circle().strokeBorder(.white, lineWidth: 5)
                            .background(Circle().fill(Color.orange))
                            .frame(width: 76, height: 76)
                            .shadow(radius: 4)
                    }
                    .disabled(camera.status != .running)
                    .accessibilityLabel("Take photo")
                } else {
                    clubPicker
                    HStack(spacing: 12) {
                        if retakesLeft > 0 {
                            Button("Retake") {
                                retakesLeft -= 1
                                photo = nil
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                        Button(action: post) {
                            Text(busy ? "Posting…" : "Post").font(.headline).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(busy || selected.isEmpty)
                    }
                }
                if let problem {
                    Text(problem).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Morning face")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip today", action: skip).disabled(busy)
                }
            }
        }
        .task {
            selected = Set(model.clubs.map(\.id))
            if await PermissionCenter.shared.ensure(.camera) { await camera.start() } else { camera.markDenied() }
        }
        .onDisappear { camera.stop() }
        .interactiveDismissDisabled(busy)
    }

    private var clubPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Share with").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.clubs) { club in
                        let on = selected.contains(club.id)
                        Button {
                            if on { selected.remove(club.id) } else { selected.insert(club.id) }
                        } label: {
                            Text("\(club.emoji) \(club.name)")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(on ? Color.orange : Color(.secondarySystemBackground), in: .capsule)
                                .foregroundStyle(on ? .white : .primary)
                        }
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
        }
        .frame(maxWidth: 420)
    }

    private func snap() {
        Task {
            if let image = await camera.capture() { photo = image } else { problem = "Couldn't take the photo. Try again." }
        }
    }

    private func post() {
        guard let photo, let jpeg = SelfieCamera.jpeg(photo) else { return }
        busy = true
        problem = nil
        Task {
            let ok = await model.perform {
                try await model.service.postMorning(jpeg: jpeg, day: model.today, clubs: Array(selected))
            }
            busy = false
            if ok {
                model.didDecidePhoto(.posted)
                Telemetry.shared.send(.action(.photoPosted(clubCount: selected.count)))
                dismiss()
            } else {
                problem = model.error
            }
        }
    }

    private func skip() {
        busy = true
        Task {
            if await model.perform({ try await model.service.skipMorning(day: model.today) }) {
                model.didDecidePhoto(.skipped)
                Telemetry.shared.send(.action(.photoSkipped))
            }
            busy = false
            dismiss()
        }
    }
}

/// Front camera with photo capture.
@MainActor
@Observable
final class SelfieCamera: NSObject {
    enum Status { case starting, running, denied, unavailable }
    private(set) var status: Status = .starting
    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored private let output = AVCapturePhotoOutput()
    @ObservationIgnored private var continuation: CheckedContinuation<UIImage?, Never>?
    @ObservationIgnored private let queue = DispatchQueue(label: "be.gloop.selfie")

    func markDenied() { status = .denied }

    func start() async {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {
            status = .unavailable
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        let session = session
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            queue.async {
                session.startRunning()
                done.resume()
            }
        }
        status = session.isRunning ? .running : .unavailable
    }

    func stop() {
        let session = session
        queue.async { session.stopRunning() }
    }

    func capture() async -> UIImage? {
        guard status == .running, continuation == nil else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            // Save selfies the way the user saw themselves in the preview.
            if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
            if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90  // portrait
            }
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            output.capturePhoto(with: settings, delegate: self)
        }
    }

    fileprivate func finish(_ image: UIImage?) {
        continuation?.resume(returning: image)
        continuation = nil
    }

    /// Mirrored like the preview, max 1080 px on the long side, JPEG ~150 KB.
    nonisolated static func jpeg(_ image: UIImage, maxSide: CGFloat = 1080) -> Data? {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.72)
    }
}

extension SelfieCamera: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        let data = photo.fileDataRepresentation()
        Task { @MainActor in
            self.finish(data.flatMap(UIImage.init(data:)))
        }
    }
}

/// Live preview layer for an `AVCaptureSession`.
struct CameraLayerView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
