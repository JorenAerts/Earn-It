import AVFoundation
import Foundation

/// Keeps an alarm sounding inside the app while the mission is open (the system alarm is
/// silenced as soon as the user taps X). Generated beep pattern, no audio file needed.
/// `.playback` category plays through the silent switch.
@MainActor
final class AlarmSoundPlayer {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private var running = false

    func start() {
        guard !running else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let sampleRate = 44_100.0
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
                  let buffer = Self.beepPattern(format: format, sampleRate: sampleRate)
            else { return }
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            try engine.start()
            node.scheduleBuffer(buffer, at: nil, options: .loops)
            node.play()
            running = true
        } catch {
            running = false
        }
    }

    func stop() {
        guard running else { return }
        node.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        running = false
    }

    /// One second: three short 880 Hz beeps, then silence. Looped.
    private static func beepPattern(format: AVAudioFormat, sampleRate: Double) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = frames
        let beepStarts = [0.0, 0.22, 0.44]
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let inBeep = beepStarts.contains { t >= $0 && t < $0 + 0.15 }
            samples[i] = inBeep ? Float(sin(2 * .pi * 880 * t) * 0.7) : 0
        }
        return buffer
    }
}
