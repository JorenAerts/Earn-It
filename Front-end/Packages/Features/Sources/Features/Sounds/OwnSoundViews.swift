import AVFoundation
import Core
import Permissions
import SwiftUI
import Telemetry

// MARK: - Trim (shared by import + record)

/// Pick the ≤30 s part of a file that becomes the alarm sound: waveform with a draggable window,
/// preview, name → saved into `MySounds`.
struct TrimSoundView: View {
    let source: URL
    let kind: CustomSound.Source
    let onSaved: (CustomSound) -> Void

    @State private var name: String
    @State private var duration: Double = 0
    @State private var peaks: [Float] = []
    @State private var start: Double = 0
    @State private var length: Double = CustomSoundLibrary.maxDuration
    @State private var preview = ClipPreview()
    @State private var saving = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    init(source: URL, suggestedName: String, kind: CustomSound.Source, onSaved: @escaping (CustomSound) -> Void) {
        self.source = source
        self.kind = kind
        self.onSaved = onSaved
        _name = State(initialValue: suggestedName)
    }

    private var window: (start: Double, length: Double) {
        ClipProcessing.window(start: start, length: length, fileDuration: duration)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
            }
            Section {
                if peaks.isEmpty && error == nil {
                    ProgressView("Reading audio…").frame(maxWidth: .infinity)
                } else {
                    Waveform(peaks: peaks, duration: duration, window: window) { newStart in
                        start = newStart
                    }
                    .frame(height: 90)
                    HStack {
                        Text(timeText(window.start))
                        Spacer()
                        Text("\(Int(window.length.rounded())) s")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Text(timeText(window.start + window.length))
                    }
                    .font(.caption.monospacedDigit())
                    if duration > window.length {
                        Slider(value: $start, in: 0...max(0, duration - window.length)) { Text("Start") }
                    }
                    Stepper("Length: \(Int(length)) s", value: $length, in: 3...CustomSoundLibrary.maxDuration, step: 1)
                    Button {
                        preview.toggle(url: source, start: window.start, length: window.length)
                    } label: {
                        Label(preview.isPlaying ? "Stop preview" : "Play this part",
                              systemImage: preview.isPlaying ? "stop.fill" : "play.fill")
                    }
                }
            } header: {
                Text("Choose the part to wake up to")
            } footer: {
                Text("Alarm sounds can be up to 30 seconds; the part repeats while the alarm rings. Only use audio you have the rights to.")
            }
            if let error {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Trim sound")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(saving ? "Saving…" : "Save", action: save)
                    .disabled(saving || duration == 0 || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .task { await load() }
        .onDisappear { preview.stop() }
    }

    private func load() async {
        let url = source
        do {
            let result = try await Task.detached { () -> (Double, [Float]) in
                (try AudioClipExporter.duration(of: url), try AudioClipExporter.overview(of: url))
            }.value
            duration = result.0
            peaks = result.1
            length = min(CustomSoundLibrary.maxDuration, duration)
        } catch {
            self.error = AudioClipError.unreadable.localizedDescription
        }
    }

    private func save() {
        saving = true
        preview.stop()
        let (s, l) = window
        let url = source
        let temp = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).caf")
        Task {
            do {
                let seconds = try await Task.detached { try AudioClipExporter.export(from: url, start: s, length: l, to: temp) }.value
                let sound = try MySounds.shared.add(file: temp, name: name.trimmingCharacters(in: .whitespaces),
                                                    duration: seconds, source: kind)
                Telemetry.shared.send(.action(kind == .recorded ? .soundRecorded : .soundImported))
                onSaved(sound)
                dismiss()
            } catch {
                self.error = error.localizedDescription
                saving = false
            }
        }
    }

    private func timeText(_ t: Double) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

/// Bars + highlighted window; drag to move the window.
private struct Waveform: View {
    let peaks: [Float]
    let duration: Double
    let window: (start: Double, length: Double)
    let onMove: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x0 = duration > 0 ? w * window.start / duration : 0
            let ww = duration > 0 ? w * window.length / duration : w
            ZStack(alignment: .leading) {
                Canvas { ctx, size in
                    guard !peaks.isEmpty else { return }
                    let bar = size.width / CGFloat(peaks.count)
                    for (i, p) in peaks.enumerated() {
                        let h = max(2, CGFloat(p) * size.height)
                        let rect = CGRect(x: CGFloat(i) * bar, y: (size.height - h) / 2, width: max(1, bar - 1), height: h)
                        ctx.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(.secondary.opacity(0.5)))
                    }
                }
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.22))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.orange, lineWidth: 2))
                    .frame(width: max(12, ww))
                    .offset(x: x0)
            }
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                guard duration > 0 else { return }
                let center = value.location.x / w * duration
                onMove(max(0, center - window.length / 2))
            })
        }
        .accessibilityElement()
        .accessibilityLabel("Waveform. Selected part starts at \(Int(window.start)) seconds.")
    }
}

/// Plays part of a file for previewing.
@MainActor
@Observable
final class ClipPreview {
    private(set) var isPlaying = false
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var stopTask: Task<Void, Never>?

    func toggle(url: URL, start: Double, length: Double) {
        if isPlaying { stop(); return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.currentTime = start
        player.play()
        self.player = player
        isPlaying = true
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(length))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    func stop() {
        stopTask?.cancel()
        player?.stop()
        player = nil
        isPlaying = false
    }
}

// MARK: - Record

/// Record up to 30 s with the microphone, then trim and save.
struct RecordSoundView: View {
    let onSaved: (CustomSound) -> Void
    @State private var recorder = MicRecorder()
    @State private var recordedURL: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()
                Text(recorder.isRecording ? "Recording…" : (recordedURL == nil ? "Record a wake-up message" : "Done"))
                    .font(.title2.bold())
                Text("e.g. \"Rise and shine! Mission time!\" Max 30 seconds.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                ZStack {
                    Circle().fill(Color.red.opacity(0.15))
                        .frame(width: 160 + CGFloat(recorder.level) * 80, height: 160 + CGFloat(recorder.level) * 80)
                        .animation(.easeOut(duration: 0.1), value: recorder.level)
                    Button {
                        if recorder.isRecording {
                            recordedURL = recorder.stop()
                        } else {
                            recordedURL = nil
                            Task { await recorder.start() }
                        }
                    } label: {
                        Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 44)).foregroundStyle(.white)
                            .frame(width: 120, height: 120)
                            .background(Color.red, in: .circle)
                    }
                    .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")
                }
                .frame(height: 240)
                Text(String(format: "0:%02d / 0:30", Int(recorder.elapsed)))
                    .font(.headline.monospacedDigit())
                if recorder.message != nil {
                    PermissionBanner(kind: .microphone, message: recorder.message ?? "")
                }
                Spacer()
                if let url = recordedURL {
                    NavigationLink {
                        TrimSoundView(source: url, suggestedName: "My wake-up message", kind: .recorded) { sound in
                            onSaved(sound)
                            dismiss()
                        }
                    } label: {
                        Text("Next").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(24)
            .navigationTitle("Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { recorder.cancel(); dismiss() } } }
        }
        .onChange(of: recorder.finishedURL) { _, url in if let url { recordedURL = url } }
    }
}

@MainActor
@Observable
final class MicRecorder {
    private(set) var isRecording = false
    private(set) var level: Float = 0
    private(set) var elapsed: Double = 0
    private(set) var message: String?
    /// Set when the 30 s limit stopped the recording.
    private(set) var finishedURL: URL?
    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var meterTask: Task<Void, Never>?

    func start() async {
        message = nil
        finishedURL = nil
        guard await AVAudioApplication.requestRecordPermission() else {
            message = "Microphone access is off. Turn it on in Settings to record."
            return
        }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory.appending(path: "recording-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100,
                                           AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.record(forDuration: CustomSoundLibrary.maxDuration)
            self.recorder = recorder
            isRecording = true
            elapsed = 0
            meterTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(50))
                    guard let self, let r = self.recorder else { return }
                    if !r.isRecording {
                        self.finishedURL = self.stop()
                        return
                    }
                    r.updateMeters()
                    self.level = max(0, (r.averagePower(forChannel: 0) + 50) / 50)
                    self.elapsed = r.currentTime
                }
            }
        } catch {
            message = "Couldn't start recording: \(error.localizedDescription)"
        }
    }

    /// Stops and returns the recorded file.
    func stop() -> URL? {
        meterTask?.cancel()
        let url = recorder?.url
        recorder?.stop()
        recorder = nil
        isRecording = false
        level = 0
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        return url
    }

    func cancel() {
        if let url = stop() { try? FileManager.default.removeItem(at: url) }
    }
}
