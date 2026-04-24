import Foundation

public enum FixtureWriter {

    public struct Output: Equatable, Sendable {
        public let wav: URL
        public let sidecar: URL
    }

    /// Catalog-driven take. Filename: `<pattern.filenameStem>-take<N>.wav/.json`
    /// inside `directory`. Creates `directory` if missing.
    public static func writeTake(
        samples: [Float],
        metadata: FixtureMetadata,
        pattern: FixturePattern,
        takeNumber: Int,
        into directory: URL
    ) throws -> Output {
        try ensureDirectory(directory)
        let basename = "\(pattern.filenameStem)-take\(takeNumber)"
        return try write(
            samples: samples, metadata: metadata,
            basename: basename, directory: directory
        )
    }

    /// Ad-hoc take. Filename: `<ISO timestamp>-<targetSlug>-<labelSlug>[-<subSlug>].wav`.
    /// Kept for CLI utilities; the recorder app uses `writeTake` instead.
    public static func writeAdHoc(
        samples: [Float],
        metadata: FixtureMetadata,
        into directory: URL
    ) throws -> Output {
        try ensureDirectory(directory)
        return try write(
            samples: samples, metadata: metadata,
            basename: adHocBasename(for: metadata),
            directory: directory
        )
    }

    private static func ensureDirectory(_ directory: URL) throws {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
    }

    private static func write(
        samples: [Float], metadata: FixtureMetadata,
        basename: String, directory: URL
    ) throws -> Output {
        let wavURL = directory.appendingPathComponent(basename + ".wav")
        let sidecarURL = directory.appendingPathComponent(basename + ".json")

        try encodeWAV(samples: samples, sampleRate: metadata.sampleRate)
            .write(to: wavURL, options: .atomic)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let json = try encoder.encode(metadata)
        try json.write(to: sidecarURL, options: .atomic)

        return Output(wav: wavURL, sidecar: sidecarURL)
    }

    private static func adHocBasename(for meta: FixtureMetadata) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let ts = formatter.string(from: meta.capturedAt)
        let target = FilenameSlug.ascii(ipa: meta.targetPhonemeIPA)
        let label = meta.expectedLabel.rawValue
        if let sub = meta.substitutePhonemeIPA {
            return "\(ts)-\(target)-\(label)-\(FilenameSlug.ascii(ipa: sub))"
        }
        return "\(ts)-\(target)-\(label)"
    }

    // 16-bit PCM little-endian mono RIFF/WAVE encoder — matches the shape
    // AVAudioFile(forReading:) can parse.
    private static func encodeWAV(samples: [Float], sampleRate: Double) -> Data {
        var data = Data()
        let byteRate = UInt32(sampleRate) * 2
        let blockAlign: UInt16 = 2
        let bitsPerSample: UInt16 = 16
        let subchunk2Size = UInt32(samples.count) * UInt32(blockAlign)
        let chunkSize = 36 + subchunk2Size

        data.append(contentsOf: Array("RIFF".utf8))
        data.append(contentsOf: chunkSize.littleEndianBytes)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.append(contentsOf: UInt32(16).littleEndianBytes)
        data.append(contentsOf: UInt16(1).littleEndianBytes)
        data.append(contentsOf: UInt16(1).littleEndianBytes)
        data.append(contentsOf: UInt32(sampleRate).littleEndianBytes)
        data.append(contentsOf: byteRate.littleEndianBytes)
        data.append(contentsOf: blockAlign.littleEndianBytes)
        data.append(contentsOf: bitsPerSample.littleEndianBytes)
        data.append(contentsOf: Array("data".utf8))
        data.append(contentsOf: subchunk2Size.littleEndianBytes)

        for f in samples {
            let clamped = max(-1, min(1, f))
            let i: Int16 = clamped == -1 ? .min : Int16(clamped * Float(Int16.max))
            data.append(contentsOf: i.littleEndianBytes)
        }
        return data
    }
}

extension FixedWidthInteger {
    fileprivate var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.littleEndian) { Array($0) }
    }
}
