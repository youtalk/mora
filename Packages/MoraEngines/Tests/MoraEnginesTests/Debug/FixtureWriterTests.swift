#if DEBUG
import AVFoundation
import XCTest

@testable import MoraEngines

final class FixtureWriterTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSlugMapsIpaToAscii() {
        XCTAssertEqual(FixtureWriter.filenameSlug(ipa: "ʃ"), "sh")
        XCTAssertEqual(FixtureWriter.filenameSlug(ipa: "θ"), "th")
        XCTAssertEqual(FixtureWriter.filenameSlug(ipa: "æ"), "ae")
        XCTAssertEqual(FixtureWriter.filenameSlug(ipa: "ʌ"), "uh")
        XCTAssertEqual(FixtureWriter.filenameSlug(ipa: "r"), "r")
    }

    func testWavRoundTripsThroughAvAudioFile() throws {
        let samples: [Float] = (0..<1_600).map { sinf(Float($0) * 2 * .pi * 440 / 16_000) }
        let meta = FixtureMetadata(
            capturedAt: Date(timeIntervalSince1970: 1_714_000_000),
            targetPhonemeIPA: "ʃ", expectedLabel: .matched,
            substitutePhonemeIPA: nil, wordSurface: "ship",
            sampleRate: 16_000, durationSeconds: 0.1, speakerTag: .adult
        )

        let urls = try FixtureWriter.write(
            samples: samples, metadata: meta, into: tempDir
        )

        let file = try AVAudioFile(forReading: urls.wav)
        XCTAssertEqual(file.fileFormat.sampleRate, 16_000)
        XCTAssertEqual(file.fileFormat.channelCount, 1)
        XCTAssertEqual(Int(file.length), samples.count)
    }

    func testSidecarJsonMatchesMetadata() throws {
        let meta = FixtureMetadata(
            capturedAt: Date(timeIntervalSince1970: 1_714_000_000),
            targetPhonemeIPA: "r", expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "l", wordSurface: "right",
            sampleRate: 16_000, durationSeconds: 0.1, speakerTag: .adult
        )
        let urls = try FixtureWriter.write(
            samples: Array(repeating: 0.0, count: 1_600),
            metadata: meta, into: tempDir
        )

        let data = try Data(contentsOf: urls.sidecar)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FixtureMetadata.self, from: data)
        XCTAssertEqual(decoded, meta)
    }

    func testFilenameIncludesTargetAndLabelSlugs() throws {
        let meta = FixtureMetadata(
            capturedAt: Date(timeIntervalSince1970: 1_714_000_000),
            targetPhonemeIPA: "ʃ", expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "s", wordSurface: "ship",
            sampleRate: 16_000, durationSeconds: 0.1, speakerTag: .adult
        )
        let urls = try FixtureWriter.write(
            samples: Array(repeating: 0.0, count: 1_600),
            metadata: meta, into: tempDir
        )
        XCTAssertTrue(urls.wav.lastPathComponent.contains("sh"))
        XCTAssertTrue(urls.wav.lastPathComponent.contains("substitutedBy"))
        XCTAssertTrue(urls.wav.lastPathComponent.contains("s.wav"))
        XCTAssertEqual(
            urls.wav.deletingPathExtension().lastPathComponent,
            urls.sidecar.deletingPathExtension().lastPathComponent
        )
    }
}
#endif
