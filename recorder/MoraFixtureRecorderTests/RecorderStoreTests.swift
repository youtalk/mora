import MoraFixtures
import XCTest
@testable import MoraFixtureRecorder

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
        let dir = tempDir
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
        let childDir = tempDir
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
        let dir = tempDir
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
}
