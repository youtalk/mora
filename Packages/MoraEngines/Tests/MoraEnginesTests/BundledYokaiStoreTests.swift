// Packages/MoraEngines/Tests/MoraEnginesTests/BundledYokaiStoreTests.swift
import XCTest
@testable import MoraEngines
@testable import MoraCore

final class BundledYokaiStoreTests: XCTestCase {
    func test_returnsFiveYokaiFromBundledCatalog() throws {
        let store = try BundledYokaiStore()
        XCTAssertEqual(store.catalog().count, 5)
    }

    func test_portraitURLIsNilWhenAssetMissing_preR4() throws {
        let store = try BundledYokaiStore()
        // R4 ships portraits; until then URLs are nil and UI falls back to placeholders.
        XCTAssertNil(store.portraitURL(for: "sh"))
    }
}
