import AVFoundation
import Core
import Foundation

/// Pure DSP helpers for own sounds (tested).
enum ClipProcessing {
    static let outputRate: Double = 22_050
    static let fade: Double = 0.5
    static let targetPeak: Float = 0.89

    /// Fade in/out and peak-normalise, in place semantics on a copy.
    static func finish(_ samples: [Float], sampleRate: Double) -> [Float] {
        guard !samples.isEmpty else { return samples }
        var out = samples
        let fadeFrames = min(Int(fade * sampleRate), out.count / 2)
        for i in 0..<fadeFrames {
            let g = Float(i) / Float(max(1, fadeFrames))
            out[i] *= g
            out[out.count - 1 - i] *= g
        }
        let peak = out.map(abs).max() ?? 0
        guard peak > 0.0001 else { return out }
        let gain = targetPeak / peak
        return out.map { $0 * gain }
    }

    /// `count` max-amplitude buckets (0…1) for drawing a waveform.
    static func peaks(_ samples: [Float], count: Int) -> [Float] {
        guard !samples.isEmpty, count > 0 else { return [] }
        let size = max(1, samples.count / count)
        var result: [Float] = []
        var i = 0
        while i < samples.count, result.count < count {
            let end = min(samples.count, i + size)
            result.append(samples[i..<end].map(abs).max() ?? 0)
            i = end
        }
        let top = result.max() ?? 1
        return top > 0 ? result.map { $0 / top } : result
    }

    /// Clamps a requested clip to the file and the 30 s alarm limit.
    static func window(start: Double, length: Double, fileDuration: Double) -> (start: Double, length: Double) {
        let len = min(length, CustomSoundLibrary.maxDuration, fileDuration)
        let s = max(0, min(start, fileDuration - len))
        return (s, max(0, len))
    }
}

enum AudioClipError: LocalizedError {
    case unreadable, empty

    var errorDescription: String? {
        switch self {
        case .unreadable: "This file can't be used. Copy-protected music (like Apple Music downloads) can't be imported."
        case .empty: "The selected part is silent or empty."
        }
    }
}

/// Reads any audio file iOS can decode (mp3, m4a, wav, caf…), cuts [start, start+length],
/// mixes to mono, resamples to 22.05 kHz and writes a 16-bit CAF (the alarm sound format).
enum AudioClipExporter {
    /// Duration of an audio file in seconds.
    static func duration(of url: URL) throws -> Double {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.processingFormat.sampleRate
    }

    /// Mono samples at `rate` for the whole file (used for the waveform; long files are decimated).
    static func overview(of url: URL, buckets: Int = 120) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let chunk: AVAudioFrameCount = 65_536
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else { throw AudioClipError.unreadable }
        let total = max(1, Int(file.length))
        let perBucket = max(1, total / buckets)
        var peaks: [Float] = []
        var current: Float = 0
        var inBucket = 0
        while file.framePosition < file.length {
            try file.read(into: buffer, frameCount: chunk)
            guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { break }
            for i in 0..<Int(buffer.frameLength) {
                current = max(current, abs(channels[0][i]))
                inBucket += 1
                if inBucket == perBucket {
                    peaks.append(current)
                    current = 0
                    inBucket = 0
                }
            }
        }
        let top = peaks.max() ?? 1
        return top > 0 ? peaks.map { $0 / top } : peaks
    }

    /// Exports the clip. Returns its length in seconds.
    @discardableResult
    static func export(from source: URL, start: Double, length: Double, to destination: URL) throws -> Double {
        let file: AVAudioFile
        do { file = try AVAudioFile(forReading: source) } catch { throw AudioClipError.unreadable }
        let inFormat = file.processingFormat
        let fileDuration = Double(file.length) / inFormat.sampleRate
        let clip = ClipProcessing.window(start: start, length: length, fileDuration: fileDuration)
        let frames = AVAudioFrameCount(clip.length * inFormat.sampleRate)
        guard frames > 0, let input = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: frames) else { throw AudioClipError.empty }
        file.framePosition = AVAudioFramePosition(clip.start * inFormat.sampleRate)
        try file.read(into: input, frameCount: frames)

        // Mono mixdown.
        guard let channels = input.floatChannelData else { throw AudioClipError.unreadable }
        let n = Int(input.frameLength), channelCount = Int(inFormat.channelCount)
        var mono = [Float](repeating: 0, count: n)
        for c in 0..<channelCount {
            for i in 0..<n { mono[i] += channels[c][i] / Float(channelCount) }
        }

        // Resample to 22.05 kHz.
        guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: inFormat.sampleRate, channels: 1),
              let outFormat = AVAudioFormat(standardFormatWithSampleRate: ClipProcessing.outputRate, channels: 1),
              let monoBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: AVAudioFrameCount(n)),
              let converter = AVAudioConverter(from: monoFormat, to: outFormat)
        else { throw AudioClipError.unreadable }
        monoBuffer.frameLength = AVAudioFrameCount(n)
        mono.withUnsafeBufferPointer { src in
            monoBuffer.floatChannelData![0].update(from: src.baseAddress!, count: n)
        }
        let outCapacity = AVAudioFrameCount(Double(n) * ClipProcessing.outputRate / inFormat.sampleRate) + 1024
        guard let resampled = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: outCapacity) else { throw AudioClipError.unreadable }
        var fed = false
        var conversionError: NSError?
        converter.convert(to: resampled, error: &conversionError) { _, status in
            if fed { status.pointee = .endOfStream; return nil }
            fed = true
            status.pointee = .haveData
            return monoBuffer
        }
        if let conversionError { throw conversionError }

        let count = Int(resampled.frameLength)
        let finished = ClipProcessing.finish(Array(UnsafeBufferPointer(start: resampled.floatChannelData![0], count: count)),
                                             sampleRate: ClipProcessing.outputRate)
        guard finished.contains(where: { abs($0) > 0.001 }) else { throw AudioClipError.empty }
        finished.withUnsafeBufferPointer { src in
            resampled.floatChannelData![0].update(from: src.baseAddress!, count: count)
        }

        try? FileManager.default.removeItem(at: destination)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: ClipProcessing.outputRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let out = try AVAudioFile(forWriting: destination, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        try out.write(from: resampled)
        return Double(count) / ClipProcessing.outputRate
    }
}
