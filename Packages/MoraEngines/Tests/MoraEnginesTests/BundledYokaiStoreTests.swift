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
        XCTAssertEqual(yokai.count, 5)

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
                XCTAssertTrue(
                    url.lastPathComponent.hasSuffix(".m4a"),
                    "Expected .m4a extension for yokai '\(y.id)' clip '\(key.rawValue)': \(url.lastPathComponent)"
                )
                resolvedCount += 1
            }
        }
        // 5 yokai × 8 clip keys = 40 voice clips — matches the self-review checklist
        // in docs/superpowers/plans/2026-04-24-rpg-yokai-voice-follow-up.md
        XCTAssertEqual(resolvedCount, 40)
    }

    func test_voiceClipURL_returnsNilForUnknownYokaiID() throws {
        let store = try BundledYokaiStore()
        // voiceClipURL has no placeholder fallback (unlike portraitURL), so an
        // unknown id must return nil — this locks in that intentional asymmetry.
        XCTAssertNil(store.voiceClipURL(for: "__no_such_yokai__", clip: .greet))
    }
}
