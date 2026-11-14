import AVFoundation
import Core
import Foundation
import MusicKit

/// The in-app continuation of the alarm (after X silences the system alarm).
@MainActor
public protocol AlarmSounding: AnyObject {
    var isPlaying: Bool { get }
    /// Loop `sound` until `stop()`. Switching sound while playing restarts with the new one.
    func start(_ sound: SoundChoice)
    func stop()
}

/// Loops the alarm's tone — the same file AlarmKit rings with — until the mission is done.
/// Keeps going when the app is backgrounded or the phone is locked (`UIBackgroundModes: audio`),
/// through the silent switch (`.playback`), and resumes after interruptions such as calls.
@MainActor
public final class AlarmSoundPlayer: AlarmSounding {
    private var player: AVAudioPlayer?
    private var current: SoundChoice?
    private var musicPlaying = false
    private var musicTask: Task<Void, Never>?
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

    /// File to loop in the app: built-in from the bundle, own sounds from Library/Sounds,
    /// Apple Music falls back to its tone (music playback is handled separately).
    /// A missing own sound falls back to Classic Beep, so the alarm is never silent.
    static func fileURL(for sound: SoundChoice) -> URL? {
        func bundled(_ s: AlarmSound) -> URL? { Bundle.main.url(forResource: s.resourceName, withExtension: "caf") }
        switch sound {
        case .builtIn(let s): return bundled(s)
        case .custom(let id, _):
            let url = CustomSoundLibrary.url(for: id)
            return FileManager.default.fileExists(atPath: url.path()) ? url : bundled(.classic)
        case .appleMusic(let pick): return bundled(pick.fallback)
        }
    }

    public func start(_ sound: SoundChoice) {
        shouldPlay = true
        if current != sound {
            player?.stop()
            player = nil
            stopMusic()
            current = sound
        }
        if !isPlaying && !musicPlaying { play() }
        if case .appleMusic(let pick) = sound, !musicPlaying, musicTask == nil {
            // The fallback tone plays right away; the song takes over once Apple Music is ready.
            musicTask = Task { [weak self] in await self?.startMusic(pick) }
        }
    }

    /// Apple Music subscribers only; any failure leaves the fallback tone playing.
    private func startMusic(_ pick: AppleMusicPick) async {
        defer { musicTask = nil }
        guard MusicAuthorization.currentStatus == .authorized,
              let subscription = try? await MusicSubscription.current, subscription.canPlayCatalogContent
        else { return }
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(pick.songID))
        guard let song = try? await request.response().items.first, shouldPlay,
              case .appleMusic(let still) = current, still == pick
        else { return }
        let music = ApplicationMusicPlayer.shared
        music.queue = [song]
        music.state.repeatMode = .one
        do {
            try await music.prepareToPlay()
            music.playbackTime = pick.startOffset
            try await music.play()
            guard shouldPlay else { music.stop(); return }
            player?.stop()
            player = nil
            musicPlaying = true
        } catch {
            // keep the fallback tone
        }
    }

    private func stopMusic() {
        musicTask?.cancel()
        musicTask = nil
        if musicPlaying { ApplicationMusicPlayer.shared.stop() }
        musicPlaying = false
    }

    public func stop() {
        shouldPlay = false
        stopMusic()
        guard let player else { return }
        player.stop()
        self.player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func play() {
        guard let sound = current, let url = Self.fileURL(for: sound) else { return }
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
    public private(set) var lastSound: SoundChoice?
    public init() {}
    public func start(_ sound: SoundChoice) {
        isPlaying = true
        lastSound = sound
    }
    public func stop() { isPlaying = false }
}
