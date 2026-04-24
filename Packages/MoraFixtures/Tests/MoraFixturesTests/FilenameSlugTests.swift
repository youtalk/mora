import XCTest

@testable import MoraFixtures

final class FilenameSlugTests: XCTestCase {

    func testMapsShToSh() { XCTAssertEqual(FilenameSlug.ascii(ipa: "ʃ"), "sh") }
    func testMapsThToTh() { XCTAssertEqual(FilenameSlug.ascii(ipa: "θ"), "th") }
    func testMapsAeToAe() { XCTAssertEqual(FilenameSlug.ascii(ipa: "æ"), "ae") }
    func testMapsUhToUh() { XCTAssertEqual(FilenameSlug.ascii(ipa: "ʌ"), "uh") }
    func testMapsIhToIh() { XCTAssertEqual(FilenameSlug.ascii(ipa: "ɪ"), "ih") }
    func testMapsEhToEh() { XCTAssertEqual(FilenameSlug.ascii(ipa: "ɛ"), "eh") }
    func testMapsAwToAw() { XCTAssertEqual(FilenameSlug.ascii(ipa: "ɔ"), "aw") }
    func testMapsAhToAh() { XCTAssertEqual(FilenameSlug.ascii(ipa: "ɑ"), "ah") }
    func testMapsErToEr() {
        XCTAssertEqual(FilenameSlug.ascii(ipa: "ɜ"), "er")
        XCTAssertEqual(FilenameSlug.ascii(ipa: "ɚ"), "er")
    }
    func testMapsNgToNg() { XCTAssertEqual(FilenameSlug.ascii(ipa: "ŋ"), "ng") }
    func testMapsZhToZh() { XCTAssertEqual(FilenameSlug.ascii(ipa: "ʒ"), "zh") }
    func testPassesThroughUnmapped() {
        XCTAssertEqual(FilenameSlug.ascii(ipa: "r"), "r")
        XCTAssertEqual(FilenameSlug.ascii(ipa: "l"), "l")
        XCTAssertEqual(FilenameSlug.ascii(ipa: "k"), "k")
    }
}
