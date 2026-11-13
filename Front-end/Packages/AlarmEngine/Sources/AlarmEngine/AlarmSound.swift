import AVFoundation
import Core
import Foundation

/// The in-app continuation of the alarm (after X silences the system alarm).
@MainActor
public protocol AlarmSounding: AnyObject {
    var isPlaying: Bool { get }
    /// Loop `sound` until `stop()`. Switching sound while playing restarts with the new one.
    func start(_ sound: AlarmSound)
    func stop()
}

/// Loops the alarm's tone — the same file AlarmKit rings with — until the mission is done.
/// Keeps going when the app is backgrounded or the phone is locked (`UIBackgroundModes: audio`),
/// through the silent switch (`.playback`), and resumes after interruptions such as calls.
@MainActor
public final class AlarmSoundPlayer: AlarmSounding {
    private var player: AVAudioPlayer?
    private var current: AlarmSound?
    private var shouldPlay = false
    private var interruptionObserver: NSObjectProtocol?

    public init() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let ended = raw.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .ended
            MainActor.assumeIsolated {
                if ended, let self, self.shouldPlay { self.play() }
            }
        }
    }

    public var isPlaying: Bool { player?.isPlaying == true }

    public func start(_ sound: AlarmSound) {
        shouldPlay = true
        if current != sound {
            player?.stop()
            player = nil
            current = sound
        }
        if !isPlaying { play() }
    }

    public func stop() {
        shouldPlay = false
        guard let player else { return }
        player.stop()
        self.player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func play() {
        guard let sound = current,
              let url = Bundle.main.url(forResource: sound.resourceName, withExtension: "caf") else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let player = try self.player ?? AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 1
            player.play()
            self.player = player
        } catch {
            player = nil
        }
    }
}

/// No-op sound for tests / previews; records calls.
@MainActor
public final class FakeAlarmSound: AlarmSounding {
    public private(set) var isPlaying = false
    public private(set) var lastSound: AlarmSound?
    public init() {}
    public func start(_ sound: AlarmSound) {
        isPlaying = true
        lastSound = sound
    }
    public func stop() { isPlaying = false }
}
