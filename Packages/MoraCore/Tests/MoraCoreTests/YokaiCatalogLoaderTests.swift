import XCTest
@testable import MoraCore

final class YokaiCatalogLoaderTests: XCTestCase {
    func test_loadsBundledFiveYokaiCatalog() throws {
        let loader = YokaiCatalogLoader.bundled()
        let catalog = try loader.load()
        XCTAssertEqual(catalog.count, 5)
        let ids = Set(catalog.map(\.id))
        XCTAssertEqual(ids, ["sh", "th", "f", "r", "short_a"])
    }

    func test_findsYokaiById() throws {
        let catalog = try YokaiCatalogLoader.bundled().load()
        let sh = catalog.first { $0.id == "sh" }
        XCTAssertEqual(sh?.grapheme, "sh")
        XCTAssertEqual(sh?.ipa, "/ʃ/")
    }
}
