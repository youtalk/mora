import MoraFixtures
import XCTest
@testable import MoraFixtureRecorder

@MainActor
final class FixtureDirectoryLayoutTests: XCTestCase {

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

    func testPatternDirectoryComposesSpeakerAndSubdirectory() {
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "aeuh-cat-correct" }!
        store.speakerTag = .adult
        XCTAssertEqual(
            store.patternDirectory(for: pattern),
            tempDir.appendingPathComponent("adult/aeuh"))
    }

    func testSpeakerDirectoryIsUnderDocuments() {
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        store.speakerTag = .child
        XCTAssertEqual(
            store.speakerDirectory(),
            tempDir.appendingPathComponent("child"))
    }
}
