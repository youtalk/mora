import AVFoundation
import Foundation
import MoraEngines

public struct FixturePair {
    public let basename: String
    public let wavURL: URL
    public let sidecarURL: URL
}

public struct LoadedFixture {
    public let pair: FixturePair
    public let metadata: FixtureMetadata
    public let samples: [Float]
    public let sampleRate: Double
}

public enum FixtureLoader {

    public static func enumerate(directory: URL) -> [FixturePair] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return [] }

        let byBasename = Dictionary(grouping: entries, by: {
            $0.deletingPathExtension().lastPathComponent
        })
        return byBasename.compactMap { basename, urls -> FixturePair? in
            let wav = urls.first { $0.pathExtension.lowercased() == "wav" }
            let json = urls.first { $0.pathExtension.lowercased() == "json" }
            guard let wav, let json else { return nil }
            return FixturePair(basename: basename, wavURL: wav, sidecarURL: json)
        }
        .sorted { $0.basename < $1.basename }
    }

    public static func load(_ pair: FixturePair) throws -> LoadedFixture {
        let metaData = try Data(contentsOf: pair.sidecarURL)
        let metadata = try JSONDecoder.iso8601.decode(FixtureMetadata.self, from: metaData)

        let (samples, sampleRate) = try readMono16kFloat(from: pair.wavURL)
        return LoadedFixture(
            pair: pair, metadata: metadata,
            samples: samples, sampleRate: sampleRate
        )
    }

    private static func readMono16kFloat(from url: URL) throws -> ([Float], Double) {
        let file = try AVAudioFile(forReading: url)
        let hardwareFormat = file.processingFormat
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000, channels: 1, interleaved: false
        ) else { throw NSError(domain: "FixtureLoader", code: 1) }

        guard let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat) else {
            throw NSError(domain: "FixtureLoader", code: 2)
        }

        guard let inBuffer = AVAudioPCMBuffer(
            pcmFormat: hardwareFormat, frameCapacity: AVAudioFrameCount(file.length)
        ) else { throw NSError(domain: "FixtureLoader", code: 3) }
        try file.read(into: inBuffer)

        let ratio = targetFormat.sampleRate / hardwareFormat.sampleRate
        let outCapacity = AVAudioFrameCount(Double(inBuffer.frameLength) * ratio) + 16
        guard let outBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat, frameCapacity: outCapacity
        ) else { throw NSError(domain: "FixtureLoader", code: 4) }

        var done = false
        let input: AVAudioConverterInputBlock = { _, outStatus in
            if done { outStatus.pointee = .noDataNow; return nil }
            done = true; outStatus.pointee = .haveData; return inBuffer
        }
        var error: NSError?
        _ = converter.convert(to: outBuffer, error: &error, withInputFrom: input)
        if let error { throw error }
        guard let channel = outBuffer.floatChannelData else {
            throw NSError(domain: "FixtureLoader", code: 5)
        }
        let samples = Array(
            UnsafeBufferPointer(start: channel[0], count: Int(outBuffer.frameLength)))
        return (samples, targetFormat.sampleRate)
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
