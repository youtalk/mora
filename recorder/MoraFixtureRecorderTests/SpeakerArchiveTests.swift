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
        let wavName = "\(pattern.filenameStem)-take1.wav"
        let jsonName = "\(pattern.filenameStem)-take1.json"
        try Data(repeating: 0, count: 16)
            .write(to: dir.appendingPathComponent(wavName))
        try Data(#"{"stub": true}"#.utf8)
            .write(to: dir.appendingPathComponent(jsonName))

        let zipURL = try store.prepareSpeakerArchive()
        XCTAssertTrue(zipURL.path.hasPrefix(FileManager.default.temporaryDirectory.path))
        XCTAssertEqual(zipURL.pathExtension, "zip")
        XCTAssertTrue(zipURL.lastPathComponent.contains("adult"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipURL.path))

        // Verify the zip payload actually contains the seeded take under
        // the expected <speaker>/<outputSubdir>/ path. iOS test targets
        // don't have `Process`, so we scan the zip bytes for the relative
        // path strings that a ZIP local file header stores in plain UTF-8.
        // This catches the failure mode where the coordinator produces a
        // zip that's syntactically valid but missing entries.
        let zipData = try Data(contentsOf: zipURL)
        let relativeDir = "\(store.speakerTag.rawValue)/\(pattern.outputSubdirectory)"
        let wavPath = "\(relativeDir)/\(wavName)"
        let jsonPath = "\(relativeDir)/\(jsonName)"
        XCTAssertNotNil(
            zipData.range(of: Data(wavPath.utf8)),
            "zip payload does not contain expected path \(wavPath)")
        XCTAssertNotNil(
            zipData.range(of: Data(jsonPath.utf8)),
            "zip payload does not contain expected path \(jsonPath)")
    }
}
