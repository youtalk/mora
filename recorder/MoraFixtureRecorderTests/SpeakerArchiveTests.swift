import MoraFixtures
import XCTest
@testable import MoraFixtureRecorder

@MainActor
final class SpeakerArchiveTests: XCTestCase {

    private var tempDir: URL!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true)
        defaults = UserDefaults(suiteName: UUID().uuidString)!
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testThrowsForEmptySpeakerDirectory() async throws {
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        store.speakerTag = .adult
        XCTAssertThrowsError(try store.prepareSpeakerArchive()) { error in
            guard case FixtureExportError.emptyDirectory = error else {
                XCTFail("expected .emptyDirectory, got \(error)")
                return
            }
        }
    }

    func testProducesZipUnderTempDirForNonEmptySpeaker() async throws {
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        store.speakerTag = .adult

        // Seed one take so the speaker directory is non-empty.
        let pattern = FixtureCatalog.v1Patterns[0]
        let dir = store.patternDirectory(for: pattern)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        try Data(repeating: 0, count: 16)
            .write(
                to: dir.appendingPathComponent(
                    "\(pattern.filenameStem)-take1.wav"))

        let zipURL = try store.prepareSpeakerArchive()
        XCTAssertTrue(zipURL.path.hasPrefix(FileManager.default.temporaryDirectory.path))
        XCTAssertEqual(zipURL.pathExtension, "zip")
        XCTAssertTrue(zipURL.lastPathComponent.contains("adult"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipURL.path))
    }
}
