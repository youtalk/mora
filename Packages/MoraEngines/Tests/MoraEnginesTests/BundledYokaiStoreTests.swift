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

    func test_voiceClipURL_resolvesForAllBundledYokaiAndClipKeys() throws {
        let store = try BundledYokaiStore()
        let yokai = store.catalog()
        XCTAssertFalse(yokai.isEmpty, "catalog() returned no yokai — bundle may be missing")

        var resolvedCount = 0
        for y in yokai {
            for key in YokaiClipKey.allCases {
                let url = try XCTUnwrap(
                    store.voiceClipURL(for: y.id, clip: key),
                    "Expected non-nil URL for yokai '\(y.id)' clip '\(key.rawValue)'"
                )
                XCTAssertTrue(
                    FileManager.default.fileExists(atPath: url.path),
                    "File not found on disk for yokai '\(y.id)' clip '\(key.rawValue)': \(url.path)"
                )
                XCTAssertEqual(
                    url.pathExtension,
                    "m4a",
                    "Expected .m4a extension for yokai '\(y.id)' clip '\(key.rawValue)': \(url.lastPathComponent)"
                )
                resolvedCount += 1
            }
        }
        // At the time of writing: 5 yokai × 8 clip keys = 40, matching the
        // self-review checklist in docs/superpowers/plans/2026-04-24-rpg-yokai-voice-follow-up.md.
        // The dynamic product keeps the assertion honest if the roster or clip-key set grows.
        let expectedCount = yokai.count * YokaiClipKey.allCases.count
        XCTAssertEqual(
            resolvedCount,
            expectedCount,
            "Expected \(yokai.count) yokai × \(YokaiClipKey.allCases.count) clip keys = \(expectedCount) URLs, got \(resolvedCount)"
        )
    }

    func test_voiceClipURL_returnsNilForUnknownYokaiID() throws {
        let store = try BundledYokaiStore()
        // voiceClipURL has no placeholder fallback (unlike portraitURL), so an
        // unknown id must return nil — this locks in that intentional asymmetry.
        XCTAssertNil(store.voiceClipURL(for: "__no_such_yokai__", clip: .greet))
    }
}
