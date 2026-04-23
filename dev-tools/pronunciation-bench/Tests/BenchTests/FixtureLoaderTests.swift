import XCTest

@testable import Bench

final class FixtureLoaderTests: XCTestCase {

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

    func testPairsWavWithJsonBySharedBasename() throws {
        try writeFile("a.wav", data: Data([0x01]))
        try writeFile("a.json", data: #"{"x":1}"#.data(using: .utf8)!)
        try writeFile("b.wav", data: Data([0x02]))  // orphan

        let pairs = FixtureLoader.enumerate(directory: tempDir)
        XCTAssertEqual(pairs.map(\.basename), ["a"])
    }

    func testIgnoresJsonWithoutWav() throws {
        try writeFile("x.json", data: #"{}"#.data(using: .utf8)!)
        XCTAssertEqual(FixtureLoader.enumerate(directory: tempDir).count, 0)
    }

    private func writeFile(_ name: String, data: Data) throws {
        try data.write(to: tempDir.appendingPathComponent(name))
    }
}
