import AVFoundation
import XCTest

@testable import MoraFixtures

final class FixtureWriterTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testWriteTakeFilename() throws {
        let samples: [Float] = Array(repeating: 0, count: 1_600)
        let pattern = FixturePattern(
            id: "rl-right-correct",
            targetPhonemeIPA: "r",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "right",
            phonemeSequenceIPA: ["r", "aɪ", "t"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "rl",
            filenameStem: "right-correct"
        )
        let meta = pattern.metadata(
            capturedAt: Date(timeIntervalSince1970: 1_714_000_000),
            sampleRate: 16_000,
            durationSeconds: 0.1,
            speakerTag: .adult
        )
        let out = try FixtureWriter.writeTake(
            samples: samples, metadata: meta,
            pattern: pattern, takeNumber: 1,
            into: tempDir
        )
        XCTAssertEqual(out.wav.lastPathComponent, "right-correct-take1.wav")
        XCTAssertEqual(out.sidecar.lastPathComponent, "right-correct-take1.json")
    }

    func testWriteTakeCreatesMissingSubdirectory() throws {
        let pattern = FixturePattern(
            id: "aeuh-cat-correct",
            targetPhonemeIPA: "æ",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "cat",
            phonemeSequenceIPA: ["k", "æ", "t"],
            targetPhonemeIndex: 1,
            outputSubdirectory: "aeuh",
            filenameStem: "cat-correct"
        )
        let targetDir = tempDir.appendingPathComponent("adult/aeuh")
        // No createDirectory — writeTake must create it.
        let meta = pattern.metadata(
            capturedAt: Date(), sampleRate: 16_000,
            durationSeconds: 0.1, speakerTag: .adult
        )
        _ = try FixtureWriter.writeTake(
            samples: Array(repeating: 0, count: 1_600),
            metadata: meta, pattern: pattern, takeNumber: 2,
            into: targetDir
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: targetDir.appendingPathComponent("cat-correct-take2.wav").path))
    }

    func testWavRoundTripsThroughAvAudioFile() throws {
        let samples: [Float] = (0..<1_600).map { sinf(Float($0) * 2 * .pi * 440 / 16_000) }
        let pattern = FixturePattern(
            id: "rl-right-correct",
            targetPhonemeIPA: "r",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "right",
            phonemeSequenceIPA: ["r", "aɪ", "t"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "rl",
            filenameStem: "right-correct"
        )
        let meta = pattern.metadata(
            capturedAt: Date(), sampleRate: 16_000,
            durationSeconds: 0.1, speakerTag: .adult
        )
        let out = try FixtureWriter.writeTake(
            samples: samples, metadata: meta,
            pattern: pattern, takeNumber: 1, into: tempDir
        )
        let file = try AVAudioFile(forReading: out.wav)
        XCTAssertEqual(file.fileFormat.sampleRate, 16_000)
        XCTAssertEqual(file.fileFormat.channelCount, 1)
        XCTAssertEqual(Int(file.length), samples.count)
    }

    func testSidecarJsonRoundTripsMetadata() throws {
        let pattern = FixturePattern(
            id: "rl-right-as-light",
            targetPhonemeIPA: "r",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "l",
            wordSurface: "right",
            phonemeSequenceIPA: ["r", "aɪ", "t"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "rl",
            filenameStem: "right-as-light"
        )
        let meta = pattern.metadata(
            capturedAt: Date(timeIntervalSince1970: 1_714_000_000),
            sampleRate: 16_000,
            durationSeconds: 0.5,
            speakerTag: .adult
        )
        let out = try FixtureWriter.writeTake(
            samples: Array(repeating: 0, count: 8_000),
            metadata: meta, pattern: pattern, takeNumber: 1,
            into: tempDir
        )
        let data = try Data(contentsOf: out.sidecar)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FixtureMetadata.self, from: data)
        XCTAssertEqual(decoded, meta)
    }

    func testWriteAdHocFilenameIncludesTargetAndLabelSlugs() throws {
        let meta = FixtureMetadata(
            capturedAt: Date(timeIntervalSince1970: 1_714_000_000),
            targetPhonemeIPA: "ʃ",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "s",
            wordSurface: "ship",
            sampleRate: 16_000,
            durationSeconds: 0.1,
            speakerTag: .adult,
            phonemeSequenceIPA: nil,
            targetPhonemeIndex: nil,
            patternID: nil
        )
        let out = try FixtureWriter.writeAdHoc(
            samples: Array(repeating: 0, count: 1_600),
            metadata: meta, into: tempDir
        )
        XCTAssertTrue(out.wav.lastPathComponent.contains("sh"))
        XCTAssertTrue(out.wav.lastPathComponent.contains("substitutedBy"))
        XCTAssertTrue(out.wav.lastPathComponent.contains("s.wav"))
    }
}
