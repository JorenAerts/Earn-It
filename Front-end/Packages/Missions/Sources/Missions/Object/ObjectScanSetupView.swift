import Core
import SwiftUI
import UIKit
import Vision

/// Guided registration of the user's item: name it, then 5 shots from different angles.
/// Each shot is checked (object found, big enough, angle actually changed) before it counts.
struct ObjectScanSetupView: View {
    @Binding var config: MissionConfig
    @Environment(\.dismiss) private var dismiss
    @State private var model = ScanSetupModel()
    @State private var name = ""
    @State private var phase: Phase = .name
    @State private var testing = false
    @FocusState private var nameFocused: Bool

    enum Phase { case name, capture, done }

    private let suggestions = ["Toothbrush", "Coffee cup", "Kettle", "Shoes", "Water bottle", "Book"]

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .name: nameStep
                case .capture: captureStep
                case .done: doneStep
                }
            }
            .navigationTitle("Scan your item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(phase == .done ? "Done" : "Cancel") {
                        model.stop()
                        dismiss()
                    }
                }
            }
        }
        .onDisappear { model.stop() }
    }

    // MARK: 1. Name

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Pick something you'll find every morning, away from your bed.")
                .font(.title3.weight(.semibold))
            Text("Tip: put it on a plain surface in good light. You'll take 5 photos while walking around it.")
                .foregroundStyle(.secondary)
            TextField("Item name, e.g. Toothbrush", text: $name)
                .textInputAutocapitalization(.words)
                .focused($nameFocused)
                .padding(14)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
            FlowChips(items: suggestions) { name = $0 }
            Spacer()
            Button {
                phase = .capture
                Task { await model.startCamera() }
            } label: {
                Text("Start scanning").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(20)
        .onAppear { nameFocused = true }
    }

    // MARK: 2. Capture

    private var captureStep: some View {
        VStack(spacing: 14) {
            ZStack {
                if model.cameraReady {
                    CameraPreview(session: model.camera.session)
                } else {
                    Color.black.opacity(0.85)
                    Text(model.cameraMessage ?? "Starting camera…").foregroundStyle(.white).padding()
                }
                ViewfinderCorners().padding(28)
                if model.busy { ProgressView().tint(.white).scaleEffect(1.4) }
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .frame(maxHeight: 440)
            .clipShape(.rect(cornerRadius: 24))

            VStack(spacing: 4) {
                Text("Shot \(min(model.shots.count + 1, ObjectMatchPolicy.requiredShots)) of \(ObjectMatchPolicy.requiredShots)")
                    .font(.caption.weight(.heavy)).textCase(.uppercase).foregroundStyle(.secondary)
                Text(model.prompt).font(.headline).multilineTextAlignment(.center)
                if let problem = model.problem {
                    Text(problem).font(.footnote.weight(.semibold)).foregroundStyle(.red).multilineTextAlignment(.center)
                }
            }

            HStack(spacing: 8) {
                ForEach(0..<ObjectMatchPolicy.requiredShots, id: \.self) { i in
                    Group {
                        if i < model.shots.count {
                            Image(uiImage: model.shots[i]).resizable().scaledToFit()
                        } else {
                            Image(systemName: "camera").foregroundStyle(.tertiary)
                        }
                    }
                    .frame(width: 46, height: 46)
                    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 10))
                }
            }

            Button {
                Task {
                    if await model.capture(), model.shots.count == ObjectMatchPolicy.requiredShots {
                        if let id = model.finish() {
                            config.payload = id
                            config.label = name.trimmingCharacters(in: .whitespaces)
                            phase = .done
                        }
                    }
                }
            } label: {
                Circle().fill(.white).frame(width: 66, height: 66)
                    .overlay(Circle().strokeBorder(.orange, lineWidth: 5))
                    .shadow(radius: 3)
            }
            .disabled(!model.cameraReady || model.busy)
            .accessibilityLabel("Take shot")

            #if DEBUG
            Button("Simulate scan (no camera)") {
                if let id = model.simulateFinish() {
                    config.payload = id
                    config.label = name.trimmingCharacters(in: .whitespaces)
                    phase = .done
                }
            }
            .font(.caption)
            #endif
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .sensoryFeedback(.success, trigger: model.shots.count)
        .sensoryFeedback(.error, trigger: model.problem) { _, new in new != nil }
    }

    // MARK: 3. Done

    private var doneStep: some View {
        VStack(spacing: 18) {
            Spacer()
            if let thumb = model.shots.first {
                Image(uiImage: thumb).resizable().scaledToFit()
                    .frame(width: 140, height: 140)
                    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 24))
            }
            Text("\(config.label ?? "Item") registered").font(.title2.bold())
            Text("When your alarm rings, scan it to stop the alarm. Try it now to be sure it works where you'll keep it.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Test recognition") { testing = true }.buttonStyle(.bordered)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Done").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(20)
        .sheet(isPresented: $testing) {
            NavigationStack {
                TestRecognitionView(referenceID: config.payload, label: config.label ?? "item")
                    .navigationTitle("Test")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close") { testing = false } } }
            }
        }
    }
}

private struct TestRecognitionView: View {
    let referenceID: String?
    let label: String
    @State private var recognised = false

    var body: some View {
        VStack(spacing: 16) {
            if recognised {
                Label("Recognised!", systemImage: "checkmark.circle.fill").font(.title2.bold()).foregroundStyle(.green)
            }
            ObjectMissionView(referenceID: referenceID, label: label) { result in
                if result == .success { recognised = true }
            }
            .id(recognised)
        }
        .padding(.top)
    }
}

/// Setup capture: keeps the shots, their prints and checks each new one.
@MainActor
@Observable
final class ScanSetupModel {
    private(set) var shots: [UIImage] = []
    private(set) var cameraReady = false
    private(set) var cameraMessage: String?
    private(set) var busy = false
    private(set) var problem: String?
    @ObservationIgnored let camera = CameraFeed()
    @ObservationIgnored private var prints: [VNFeaturePrintObservation] = []

    private let prompts = ["Front of the item", "Walk a bit to the left", "Now to the right", "The other side", "From above"]

    var prompt: String { prompts[min(shots.count, prompts.count - 1)] }

    func startCamera() async {
        var result = await camera.start()
        // Not running yet (still coming to the foreground / camera busy): retry for a few seconds.
        for _ in 0..<10 where result == .paused {
            cameraMessage = "Starting the camera…"
            try? await Task.sleep(for: .seconds(1))
            result = await camera.start()
        }
        switch result {
        case .running:
            cameraReady = true
            cameraMessage = nil
        case .denied: cameraMessage = "Allow camera access in Settings to scan your item."
        case .unavailable: cameraMessage = "No camera available."
        default: cameraMessage = "The camera couldn't start. Close other apps that use the camera and try again."
        }
    }

    func stop() { camera.stop() }

    /// Analyses the current frame. Returns true when the shot was accepted.
    func capture() async -> Bool {
        guard let buffer = camera.latestFrame() else { return false }
        busy = true
        problem = nil
        let box = BufferBox(buffer)
        let frame = await Task.detached { ObjectVision.analyse(box.buffer, keepCutout: true) }.value
        busy = false
        guard let frame else {
            problem = "Couldn't make out the item. Move closer and use a plain background."
            return false
        }
        if let previous = prints.last, let d = ObjectVision.distance(frame.print, previous),
           !ObjectMatchPolicy.isDistinctAngle(distanceToPrevious: d) {
            problem = "That looks the same as the last shot. Walk around the item a bit more."
            return false
        }
        prints.append(frame.print)
        shots.append(frame.cutout.map { UIImage(cgImage: $0, scale: 1, orientation: .up) } ?? UIImage())
        return true
    }

    /// Saves the reference. Returns its id.
    func finish() -> String? {
        let threshold = ObjectMatchPolicy.threshold(pairwiseDistances: ObjectVision.pairwiseDistances(prints))
        camera.stop()
        do {
            return try ObjectReferenceStore.shared.save(prints: prints, threshold: threshold, thumbnail: shots.first)
        } catch {
            problem = "Couldn't save the scan: \(error.localizedDescription)"
            return nil
        }
    }

    #if DEBUG
    /// Simulator: register a placeholder item from a generated image.
    func simulateFinish() -> String? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
        let image = renderer.image { ctx in
            UIColor.systemOrange.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 60, y: 60, width: 180, height: 180))
        }
        guard let cg = image.cgImage else { return nil }
        let request = VNGenerateImageFeaturePrintRequest()
        try? VNImageRequestHandler(cgImage: cg).perform([request])
        guard let print = request.results?.first else { return nil }
        prints = Array(repeating: print, count: ObjectMatchPolicy.requiredShots)
        shots = Array(repeating: image, count: ObjectMatchPolicy.requiredShots)
        return finish()
    }
    #endif
}

private final class BufferBox: @unchecked Sendable {
    let buffer: CVPixelBuffer
    init(_ buffer: CVPixelBuffer) { self.buffer = buffer }
}

/// Wrapping row of tappable suggestion chips.
struct FlowChips: View {
    let items: [String]
    let onTap: (String) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) { ForEach(items.prefix(3), id: \.self, content: chip) }
                HStack(spacing: 8) { ForEach(items.dropFirst(3), id: \.self, content: chip) }
            }
        }
    }

    private var chips: some View { ForEach(items, id: \.self, content: chip) }

    private func chip(_ item: String) -> some View {
        Button(item) { onTap(item) }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Color(.secondarySystemBackground), in: .capsule)
            .buttonStyle(.plain)
    }
}
