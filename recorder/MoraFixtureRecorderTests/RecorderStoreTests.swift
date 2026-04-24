import AVFoundation
import MoraCore
import MoraEngines
import MoraFixtures
import XCTest
@testable import MoraFixtureRecorder

/// Test stub for `FixtureRecorder` that avoids AVAudioEngine. `drain()`
/// returns a deterministic 24_000-sample Float32 buffer so the captured
/// state has non-empty audio for the evaluator.
@MainActor
final class StubRecorder: FixtureRecorder {
    override func start() throws { /* no-op */ }
    override func stop() { /* no-op */ }
    override func drain() -> [Float] {
        // 1.5 s of silence. `FakeRunner` doesn't inspect samples in
        // production tests — `lastSamples` on the fake still records
        // what was passed if a test needs it.
        Array(repeating: 0, count: 24_000)
    }
}

@MainActor
final class RecorderStoreTests: XCTestCase {

    private var tempDir: URL!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defaults = UserDefaults(suiteName: UUID().uuidString)!
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSpeakerTagPersistsAcrossInitializations() async throws {
        let a = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        a.speakerTag = .child
        let b = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        XCTAssertEqual(b.speakerTag, .child)
    }

    func testTakeCountIsZeroOnEmptyDirectory() async throws {
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        let pattern = FixtureCatalog.v1Patterns[0]
        XCTAssertEqual(store.takeCount(for: pattern), 0)
    }

    func testTakeCountEnumeratesDiskFiles() async throws {
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "rl-right-correct" }!

        // Seed two takes on disk for speaker = adult.
        let dir =
            tempDir
            .appendingPathComponent("adult")
            .appendingPathComponent(pattern.outputSubdirectory)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        for n in [1, 2] {
            let wav = dir.appendingPathComponent("\(pattern.filenameStem)-take\(n).wav")
            let json = dir.appendingPathComponent("\(pattern.filenameStem)-take\(n).json")
            try Data().write(to: wav)
            try Data().write(to: json)
        }

        store.speakerTag = .adult
        XCTAssertEqual(store.takeCount(for: pattern), 2)
    }

    func testCrossSpeakerIsolation() async throws {
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "rl-right-correct" }!

        // Put a file only under child/.
        let childDir =
            tempDir
            .appendingPathComponent("child")
            .appendingPathComponent(pattern.outputSubdirectory)
        try FileManager.default.createDirectory(
            at: childDir, withIntermediateDirectories: true)
        try Data().write(
            to: childDir.appendingPathComponent("\(pattern.filenameStem)-take1.wav"))
        try Data().write(
            to: childDir.appendingPathComponent("\(pattern.filenameStem)-take1.json"))

        store.speakerTag = .adult
        XCTAssertEqual(store.takeCount(for: pattern), 0)
        store.speakerTag = .child
        XCTAssertEqual(store.takeCount(for: pattern), 1)
    }

    func testNextTakeNumberHandlesGaps() async throws {
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "rl-right-correct" }!
        let dir =
            tempDir
            .appendingPathComponent("adult")
            .appendingPathComponent(pattern.outputSubdirectory)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        // Seed take1 and take4 only; take2 and take3 missing.
        for n in [1, 4] {
            try Data().write(
                to: dir.appendingPathComponent(
                    "\(pattern.filenameStem)-take\(n).wav"))
            try Data().write(
                to: dir.appendingPathComponent(
                    "\(pattern.filenameStem)-take\(n).json"))
        }
        store.speakerTag = .adult
        XCTAssertEqual(store.nextTakeNumber(for: pattern), 5)
    }

    func testTakesOnDiskSortedByTakeNumberNotLexically() async throws {
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "rl-right-correct" }!
        let dir =
            tempDir
            .appendingPathComponent("adult")
            .appendingPathComponent(pattern.outputSubdirectory)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        // Seed take1, take2, take10, take11 — lexical sort puts take10 before
        // take2, numeric sort must not.
        for n in [1, 2, 10, 11] {
            try Data().write(
                to: dir.appendingPathComponent(
                    "\(pattern.filenameStem)-take\(n).wav"))
        }
        store.speakerTag = .adult
        let names = store.takesOnDisk(for: pattern).map { $0.lastPathComponent }
        XCTAssertEqual(
            names,
            [
                "\(pattern.filenameStem)-take1.wav",
                "\(pattern.filenameStem)-take2.wav",
                "\(pattern.filenameStem)-take10.wav",
                "\(pattern.filenameStem)-take11.wav",
            ])
    }

    func testFixtureRecorderDecodeReturnsMono16kSamples() throws {
        // Write a synthetic mono 16 kHz WAV to tempDir, decode it, and
        // verify sample count matches the expected frame count.
        let url = tempDir.appendingPathComponent("synth.wav")
        let durationSeconds = 0.25
        let sampleRate = 16_000.0
        let expectedFrames = Int(durationSeconds * sampleRate)

        guard let fmt = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else { return XCTFail("AVAudioFormat init failed") }

        // Scope the writer so it deallocates (and finalizes the RIFF
        // data-chunk size in the WAV header) before decode reads.
        do {
            let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: fmt, frameCapacity: AVAudioFrameCount(expectedFrames)
            ) else { return XCTFail("AVAudioPCMBuffer alloc failed") }
            buffer.frameLength = AVAudioFrameCount(expectedFrames)
            for i in 0..<expectedFrames {
                buffer.floatChannelData![0][i] = Float(
                    sin(2 * .pi * 440 * Double(i) / sampleRate)
                )
            }
            try file.write(from: buffer)
        }

        let samples = try FixtureRecorder.decode(from: url)
        XCTAssertEqual(samples.count, expectedFrames)
        XCTAssertFalse(samples.allSatisfy { $0 == 0 })
    }

    func testDeleteTakeBumpsTakesRevision() async throws {
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "rl-right-correct" }!
        let dir =
            tempDir
            .appendingPathComponent("adult")
            .appendingPathComponent(pattern.outputSubdirectory)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        let wav = dir.appendingPathComponent("\(pattern.filenameStem)-take1.wav")
        let json = dir.appendingPathComponent("\(pattern.filenameStem)-take1.json")
        try Data().write(to: wav)
        try Data().write(to: json)
        store.speakerTag = .adult

        let before = store.takesRevision
        store.deleteTake(url: wav)
        XCTAssertEqual(store.takesRevision, before &+ 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: wav.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: json.path))
    }

    func testToggleRecordingKeepsPendingIdleInitially() async throws {
        let fake = FakeRunner()
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults,
            runner: fake
        )
        XCTAssertEqual(store.pendingVerdict, .idle)
    }

    func testStopRunsEvaluatorAndPublishesReady() async throws {
        let fake = FakeRunner()
        let expected = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "æ"),
            label: .matched, score: 100,
            coachingKey: nil, features: ["F1": 720.0],
            isReliable: true
        )
        await fake.setNextResult(expected)

        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "aeuh-cat-correct" }!
        let fixtureRecorder = StubRecorder()
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults,
            recorder: fixtureRecorder, runner: fake
        )

        // Start "recording" (StubRecorder no-op) then stop. StubRecorder
        // returns 24000 deterministic float samples when drained.
        store.toggleRecording(pattern: pattern)  // → .recording
        store.toggleRecording(pattern: pattern)  // → .captured + .evaluating

        XCTAssertEqual(store.pendingVerdict, .evaluating)

        // Wait for evaluation task to resolve.
        await store.waitForPendingVerdict(.ready(expected), timeout: 1.0)
        XCTAssertEqual(store.pendingVerdict, .ready(expected))
        let callCount = await fake.callCount
        XCTAssertEqual(callCount, 1)
    }

    func testRecordAgainCancelsStaleEvaluation() async throws {
        let fake = FakeRunner()
        await fake.waitForNextEvaluateAndSuspend()  // arm suspension

        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "aeuh-cat-correct" }!
        let fixtureRecorder = StubRecorder()
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults,
            recorder: fixtureRecorder, runner: fake
        )

        store.toggleRecording(pattern: pattern)  // → .recording
        store.toggleRecording(pattern: pattern)  // → .captured + kicks evaluate (suspended)
        XCTAssertEqual(store.pendingVerdict, .evaluating)

        // User taps Record again while evaluation is suspended.
        store.toggleRecording(pattern: pattern)  // cancels, → .recording
        XCTAssertEqual(store.pendingVerdict, .idle)

        // Release the suspended evaluator; its late-arriving result must
        // not flip pendingVerdict back to .ready(…).
        await fake.resume()
        try await Task.sleep(nanoseconds: 50_000_000)  // 50 ms MainActor drain
        XCTAssertEqual(store.pendingVerdict, .idle)
    }

    func testSaveCachesReadyVerdictInSavedVerdicts() async throws {
        let fake = FakeRunner()
        let expected = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "æ"), label: .matched,
            score: 100, coachingKey: nil,
            features: ["F1": 720.0], isReliable: true
        )
        await fake.setNextResult(expected)

        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "aeuh-cat-correct" }!
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults,
            recorder: StubRecorder(), runner: fake
        )

        store.toggleRecording(pattern: pattern)
        store.toggleRecording(pattern: pattern)
        await store.waitForPendingVerdict(.ready(expected), timeout: 1.0)

        store.save(pattern: pattern)

        let writtenWav = store.takesOnDisk(for: pattern).first!
        XCTAssertEqual(store.savedVerdicts[writtenWav], expected)
        XCTAssertEqual(store.pendingVerdict, .idle)
    }

    func testSaveBeforeReadyDoesNotCacheAndKeepsEvaluating() async throws {
        let fake = FakeRunner()
        await fake.waitForNextEvaluateAndSuspend()

        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "aeuh-cat-correct" }!
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults,
            recorder: StubRecorder(), runner: fake
        )

        store.toggleRecording(pattern: pattern)
        store.toggleRecording(pattern: pattern)  // → .evaluating, suspended
        XCTAssertEqual(store.pendingVerdict, .evaluating)

        store.save(pattern: pattern)
        let writtenWav = store.takesOnDisk(for: pattern).first!
        XCTAssertNil(store.savedVerdicts[writtenWav])
        // Save resets recordingState to .idle but leaves pendingVerdict
        // untouched so the still-running evaluator can post its result.
        XCTAssertEqual(store.pendingVerdict, .evaluating)

        await fake.resume()
    }

    func testDeleteTakeClearsSavedVerdictEntry() async throws {
        let fake = FakeRunner()
        let expected = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "æ"), label: .matched,
            score: 100, coachingKey: nil, features: [:], isReliable: true
        )
        await fake.setNextResult(expected)

        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "aeuh-cat-correct" }!
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults,
            recorder: StubRecorder(), runner: fake
        )

        store.toggleRecording(pattern: pattern)
        store.toggleRecording(pattern: pattern)
        await store.waitForPendingVerdict(.ready(expected), timeout: 1.0)
        store.save(pattern: pattern)
        let wav = store.takesOnDisk(for: pattern).first!
        XCTAssertNotNil(store.savedVerdicts[wav])

        store.deleteTake(url: wav)
        XCTAssertNil(store.savedVerdicts[wav])
    }
}
