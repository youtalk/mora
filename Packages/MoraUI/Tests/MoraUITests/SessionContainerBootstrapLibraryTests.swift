import Foundation
import XCTest

@testable import MoraCore
@testable import MoraEngines
@testable import MoraUI

final class SessionContainerBootstrapLibraryTests: XCTestCase {
    /// Two learners on the same `sh` week with disjoint single-element
    /// `interests`: one picks vehicles-mid, one picks robots-late. The
    /// bootstrap helper must return sentences from `sh × vehicles × mid`
    /// and `sh × robots × late` respectively.
    func test_resolveSentences_vehiclesMid_returnsFromVehiclesMidCell() async throws {
        let library = try SentenceLibrary()
        let vehiclesCell = await library.cell(
            phoneme: "sh", interest: "vehicles", ageBand: .mid
        )
        let cellTexts = Set(vehiclesCell?.sentences.map(\.text) ?? [])

        let resolved = try await SessionContainerView.resolveDecodeSentences(
            library: library,
            skillCode: "sh_onset",
            targetGrapheme: Grapheme(letters: "sh"),
            taughtGraphemes: CurriculumEngine.sharedV1.taughtGraphemes(beforeWeekIndex: 0),
            ageYears: 9,
            interests: ["vehicles"],
            count: 3
        )

        XCTAssertEqual(resolved.count, 3)
        for sentence in resolved {
            XCTAssertTrue(
                cellTexts.contains(sentence.text),
                "expected vehicles-mid sentence; got \(sentence.text)")
        }
    }

    func test_resolveSentences_robotsLate_returnsFromRobotsLateCell() async throws {
        let library = try SentenceLibrary()
        let robotsCell = await library.cell(
            phoneme: "sh", interest: "robots", ageBand: .late
        )
        let cellTexts = Set(robotsCell?.sentences.map(\.text) ?? [])

        let resolved = try await SessionContainerView.resolveDecodeSentences(
            library: library,
            skillCode: "sh_onset",
            targetGrapheme: Grapheme(letters: "sh"),
            taughtGraphemes: CurriculumEngine.sharedV1.taughtGraphemes(beforeWeekIndex: 0),
            ageYears: 12,
            interests: ["robots"],
            count: 3
        )

        XCTAssertEqual(resolved.count, 3)
        for sentence in resolved {
            XCTAssertTrue(
                cellTexts.contains(sentence.text),
                "expected robots-late sentence; got \(sentence.text)")
        }
    }

    /// When the library has no cells for the target (e.g. `th` at this PR's
    /// HEAD), the helper must fall back to the per-week JSON path so the
    /// session still runs. The fallback returns the existing 3 hand-authored
    /// sentences from `<skill>_week.json`.
    func test_resolveSentences_unauthoredTarget_fallsBackToScriptedProvider() async throws {
        let library = try SentenceLibrary()

        let resolved = try await SessionContainerView.resolveDecodeSentences(
            library: library,
            skillCode: "th_voiceless",
            targetGrapheme: Grapheme(letters: "th"),
            taughtGraphemes: CurriculumEngine.sharedV1.taughtGraphemes(beforeWeekIndex: 1),
            ageYears: 9,
            interests: ["robots"],
            count: 3
        )

        // Per-week JSON fallback returns 3 sentences (the existing hand-authored
        // set).  The exact texts depend on `<skill>_week.json` so we assert
        // count rather than content.
        XCTAssertEqual(resolved.count, 3)
    }

    /// Empty interests on a learner created before the interest picker — the
    /// helper must fall back to all six interest cells for the (target, band)
    /// pair and still return 3 sentences from the bundle (not the per-week
    /// JSON).
    func test_resolveSentences_emptyInterests_usesAllInterestsFromLibrary() async throws {
        let library = try SentenceLibrary()

        let resolved = try await SessionContainerView.resolveDecodeSentences(
            library: library,
            skillCode: "sh_onset",
            targetGrapheme: Grapheme(letters: "sh"),
            taughtGraphemes: CurriculumEngine.sharedV1.taughtGraphemes(beforeWeekIndex: 0),
            ageYears: 9,
            interests: [],
            count: 3
        )

        XCTAssertEqual(resolved.count, 3)

        // The empty-interests path samples uniformly from the 6 mid-band cells
        // (6 × 20 = 120 sentences). Every sentence in that pool belongs to one
        // of the six cells, so the loop below must hit at least one — this
        // confirms `resolveDecodeSentences` read from the bundle and did not
        // silently fall through to the per-week JSON.
        let resolvedTexts = Set(resolved.map(\.text))
        var hitAnyMidBundle = false
        for interest in ["animals", "dinosaurs", "vehicles", "space", "sports", "robots"] {
            let cell = await library.cell(phoneme: "sh", interest: interest, ageBand: .mid)
            let texts = Set(cell?.sentences.map(\.text) ?? [])
            if !texts.isDisjoint(with: resolvedTexts) {
                hitAnyMidBundle = true
                break
            }
        }
        XCTAssertTrue(hitAnyMidBundle, "empty-interests fallback must read from the bundle, not per-week JSON")
    }
}
