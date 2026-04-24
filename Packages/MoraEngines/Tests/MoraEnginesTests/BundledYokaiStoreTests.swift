// Packages/MoraEngines/Tests/MoraEnginesTests/BundledYokaiStoreTests.swift
import XCTest
@testable import MoraEngines
@testable import MoraCore

final class BundledYokaiStoreTests: XCTestCase {
    func test_returnsFiveYokaiFromBundledCatalog() throws {
        let store = try BundledYokaiStore()
        XCTAssertEqual(store.catalog().count, 5)
    }

    func test_portraitURLFallsBackToPlaceholderWhenAssetMissing() throws {
        let store = try BundledYokaiStore()
        let url = try XCTUnwrap(store.portraitURL(for: "__no_such_yokai__"))
        XCTAssertEqual(url.lastPathComponent, "portrait.png")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "_placeholder")
    }
}
