#if DEBUG
import Foundation

public enum FixtureWriter {

    public struct Output: Equatable, Sendable {
        public let wav: URL
        public let sidecar: URL
    }

    /// Writes a 16-bit PCM WAV and a sidecar JSON into `directory`.
    /// Returns the URLs of both files. `samples` are Float32 in [-1, 1].
    public static func write(
        samples: [Float], metadata: FixtureMetadata, into directory: URL
    ) throws -> Output {
        let basename = filename(for: metadata)
        let wavURL = directory.appendingPathComponent(basename + ".wav")
        let jsonURL = directory.appendingPathComponent(basename + ".json")

        let wavData = encodeWAV(samples: samples, sampleRate: metadata.sampleRate)
        try wavData.write(to: wavURL, options: .atomic)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(metadata)
        try jsonData.write(to: jsonURL, options: .atomic)

        return Output(wav: wavURL, sidecar: jsonURL)
    }

    // MARK: - Filename

    static func filename(for meta: FixtureMetadata) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let ts = formatter.string(from: meta.capturedAt)
        let target = filenameSlug(ipa: meta.targetPhonemeIPA)
        let label = meta.expectedLabel.rawValue
        if let sub = meta.substitutePhonemeIPA {
            return "\(ts)-\(target)-\(label)-\(filenameSlug(ipa: sub))"
        }
        return "\(ts)-\(target)-\(label)"
    }

    static func filenameSlug(ipa: String) -> String {
        switch ipa {
        case "ʃ": return "sh"
        case "θ": return "th"
        case "æ": return "ae"
        case "ʌ": return "uh"
        case "ɪ": return "ih"
        case "ɛ": return "eh"
        case "ɔ": return "aw"
        case "ɑ": return "ah"
        case "ɜ": return "er"
        case "ɚ": return "er"
        case "ŋ": return "ng"
        case "ʒ": return "zh"
        default: return ipa
        }
    }

    // MARK: - WAV encoding

    /// Encode mono Float32 samples to 16-bit PCM WAV. Layout follows the
    /// canonical RIFF/WAVE spec. Keeps dependencies minimal so the writer
    /// can run without AVFoundation on unit-test hosts.
    private static func encodeWAV(samples: [Float], sampleRate: Double) -> Data {
        var data = Data()
        let byteRate = UInt32(sampleRate) * 2  // mono, 16-bit
        let blockAlign: UInt16 = 2
        let bitsPerSample: UInt16 = 16
        let subchunk2Size = UInt32(samples.count) * UInt32(blockAlign)
        let chunkSize = 36 + subchunk2Size

        data.append(contentsOf: Array("RIFF".utf8))
        data.append(contentsOf: chunkSize.littleEndianBytes)
        data.append(contentsOf: Array("WAVE".utf8))

        data.append(contentsOf: Array("fmt ".utf8))
        data.append(contentsOf: UInt32(16).littleEndianBytes)  // subchunk1Size for PCM
        data.append(contentsOf: UInt16(1).littleEndianBytes)  // audio format PCM
        data.append(contentsOf: UInt16(1).littleEndianBytes)  // channels (mono)
        data.append(contentsOf: UInt32(sampleRate).littleEndianBytes)
        data.append(contentsOf: byteRate.littleEndianBytes)
        data.append(contentsOf: blockAlign.littleEndianBytes)
        data.append(contentsOf: bitsPerSample.littleEndianBytes)

        data.append(contentsOf: Array("data".utf8))
        data.append(contentsOf: subchunk2Size.littleEndianBytes)

        for f in samples {
            let clamped = max(-1, min(1, f))
            let i = Int16(clamped * Float(Int16.max))
            data.append(contentsOf: i.littleEndianBytes)
        }
        return data
    }
}

private extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.littleEndian) { Array($0) }
    }
}
#endif
