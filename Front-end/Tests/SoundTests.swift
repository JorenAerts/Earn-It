import AVFoundation
import Core
import Foundation
import Purchases
import Testing
@testable import Features

@Suite struct SoundChoiceTests {
    @Test func legacyStringDecodesAsBuiltIn() throws {
        let json = #"{"id":"FED23467-0B83-4401-8A74-82EB06908396","hour":7,"minute":0,"weekdays":[],"missions":[],"reArmMinutes":2,"maxReArms":15,"isEnabled":true,"sound":"chime"}"#
        let plan = try JSONDecoder().decode(AlarmPlan.self, from: Data(json.utf8))
        #expect(plan.sound == .chime)
    }

    @Test func allChoicesRoundTrip() throws {
        let choices: [SoundChoice] = [.builtIn(.furElise), .custom(id: UUID(), name: "Mum"),
                                      .appleMusic(AppleMusicPick(songID: "123", title: "Song", artist: "Band",
                                                                 startOffset: 42, fallback: .reveille))]
        for choice in choices {
            let data = try JSONEncoder().encode(choice)
            #expect(try JSONDecoder().decode(SoundChoice.self, from: data) == choice)
        }
    }

    @Test func systemAlarmFiles() {
        let id = UUID()
        #expect(SoundChoice.builtIn(.radar).systemSoundFileName == "Gloop_radar.caf")
        #expect(SoundChoice.custom(id: id, name: "x").systemSoundFileName == "custom-\(id.uuidString).caf")
        let music = SoundChoice.appleMusic(AppleMusicPick(songID: "1", title: "t", artist: "a", fallback: .chime))
        #expect(music.systemSoundFileName == AlarmSound.chime.fileName, "Apple Music rings its fallback tone")
    }

    @Test func onlyClassicIsFree() {
        let free = FeatureGate(isPro: false)
        #expect(!free.isLocked(SoundChoice.classic))
        #expect(free.isLocked(SoundChoice.builtIn(.morningMood)))
        #expect(free.isLocked(SoundChoice.custom(id: UUID(), name: "x")))
        #expect(!FeatureGate(isPro: true).isLocked(SoundChoice.custom(id: UUID(), name: "x")))
        let plan = AlarmPlan(sound: .custom(id: UUID(), name: "x"), isEnabled: true)
        let (plans, changes) = DowngradePolicy.apply(to: [plan], gate: free)
        #expect(plans[0].sound == .classic && changes.count == 1)
    }

    @Test func everyBuiltInSoundHasAFileAndCategory() {
        for sound in AlarmSound.allCases {
            #expect(Bundle.main.url(forResource: sound.resourceName, withExtension: "caf") != nil, "\(sound)")
        }
        #expect(AlarmSound.allCases.count == 11, "10 + the invite bonus sound")
    }
}

@Suite struct ClipProcessingTests {
    @Test func fadesAndNormalises() {
        let samples = [Float](repeating: 0.25, count: 22_050 * 2)
        let out = ClipProcessing.finish(samples, sampleRate: 22_050)
        #expect(out.first == 0 && out.last == 0, "faded in and out")
        #expect(abs((out.map(abs).max() ?? 0) - ClipProcessing.targetPeak) < 0.001, "normalised")
    }

    @Test func windowRespectsLimits() {
        #expect(ClipProcessing.window(start: 0, length: 60, fileDuration: 200) == (0, 30))
        #expect(ClipProcessing.window(start: 190, length: 30, fileDuration: 200) == (170, 30))
        #expect(ClipProcessing.window(start: 5, length: 30, fileDuration: 12) == (0, 12))
    }

    @Test func peaksAreNormalisedBuckets() {
        let peaks = ClipProcessing.peaks([0, 0.5, 0, 1, 0, 0.25], count: 3)
        #expect(peaks == [0.5, 1, 0.25])
    }

    @Test func exportsA30SecondAlarmFile() throws {
        // 60 s stereo 44.1 kHz sine wave in, ≤30 s mono 22.05 kHz 16-bit CAF out.
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let source = dir.appending(path: "in.caf")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let file = try AVAudioFile(forWriting: source, settings: format.settings)
        let frames = AVAudioFrameCount(44_100 * 60)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for c in 0..<2 {
            for i in 0..<Int(frames) { buffer.floatChannelData![c][i] = 0.3 * sin(Float(i) * 2 * .pi * 440 / 44_100) }
        }
        try file.write(from: buffer)

        let out = dir.appending(path: "out.caf")
        let seconds = try AudioClipExporter.export(from: source, start: 10, length: 45, to: out)
        #expect(abs(seconds - 30) < 0.1)
        let result = try AVAudioFile(forReading: out)
        #expect(result.fileFormat.sampleRate == 22_050 && result.fileFormat.channelCount == 1)
        #expect(abs(try AudioClipExporter.duration(of: out) - 30) < 0.1)
    }
}

@Suite @MainActor struct MySoundsTests {
    @Test func addRenameDelete() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let library = MySounds(directory: dir)
        let temp = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).caf")
        try Data([1, 2, 3]).write(to: temp)
        let sound = try library.add(file: temp, name: "Mum", duration: 12, source: .recorded)
        #expect(FileManager.default.fileExists(atPath: library.url(for: sound.id).path()))
        #expect(MySounds(directory: dir).sounds.map(\.name) == ["Mum"], "persisted")
        library.rename(sound.id, to: "Mom")
        #expect(library.sounds.first?.name == "Mom")
        library.delete(sound.id)
        #expect(library.sounds.isEmpty && !FileManager.default.fileExists(atPath: library.url(for: sound.id).path()))
    }
}
