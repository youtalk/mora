import Foundation
import XCTest

@testable import MoraCore
@testable import MoraEngines

final class SentenceLibrarySelectorTests: XCTestCase {
    /// Bundled library has only `sh × {6 interests} × {3 ageBands} = 18` cells
    /// at this PR's HEAD. All assertions below are framed against that state.

    /// A learner with `interests = ["vehicles"]` and `ageYears = 9` (mid band)
    /// must see only sentences from `sh × vehicles × mid`.
    func test_sentences_singleInterest_returnsFromMatchingCell() async throws {
        let library = try SentenceLibrary()

        let result = await library.sentences(
            target: "sh_onset",
            interests: ["vehicles"],
            ageYears: 9,
            excluding: [],
            count: 3
        )

        XCTAssertEqual(result.count, 3)

        let cell = await library.cell(phoneme: "sh", interest: "vehicles", ageBand: .mid)
        let cellTexts = Set(cell?.sentences.map(\.text) ?? [])
        for sentence in result {
            XCTAssertTrue(
                cellTexts.contains(sentence.text),
                "expected sentence text to come from sh × vehicles × mid; got \(sentence.text)"
            )
        }
    }

    /// A learner with `interests = ["dinosaurs", "robots"]` and `ageYears = 9`
    /// must see sentences pooled from both cells.
    func test_sentences_multipleInterests_poolsAcrossCells() async throws {
        let library = try SentenceLibrary()

        // Run multiple selections so the random shuffle has repeated chances
        // to draw from both matching cells. Each call requests up to 3
        // sentences, and this loop runs 10 times while deduping via `union`,
        // so the accumulated set is overwhelmingly likely to contain
        // sentences from both cells.
        var union: Set<String> = []
        for _ in 0..<10 {
            let result = await library.sentences(
                target: "sh_onset",
                interests: ["dinosaurs", "robots"],
                ageYears: 9,
                excluding: union,
                count: 3
            )
            for sentence in result { union.insert(sentence.text) }
        }

        let dinoCell = await library.cell(phoneme: "sh", interest: "dinosaurs", ageBand: .mid)
        let roboCell = await library.cell(phoneme: "sh", interest: "robots", ageBand: .mid)
        let dinoTexts = Set(dinoCell?.sentences.map(\.text) ?? [])
        let roboTexts = Set(roboCell?.sentences.map(\.text) ?? [])

        XCTAssertTrue(
            union.contains(where: dinoTexts.contains),
            "expected at least one dinosaur sentence in the union")
        XCTAssertTrue(
            union.contains(where: roboTexts.contains),
            "expected at least one robot sentence in the union")
    }

    /// A learner with empty `interests` falls back to all six interest cells
    /// for the resolved `(target, ageBand)`.
    func test_sentences_emptyInterests_fallsBackToAllInterests() async throws {
        let library = try SentenceLibrary()

        var union: Set<String> = []
        for _ in 0..<5 {
            let result = await library.sentences(
                target: "sh_onset",
                interests: [],
                ageYears: 9,
                excluding: union,
                count: 3
            )
            for sentence in result { union.insert(sentence.text) }
        }

        // After 5 calls × 3 sentences = 15 unique selections from a pool of
        // 6 × 20 = 120, the union must include sentences from at least two
        // distinct interest cells.
        let allMidCellTexts: [(interest: String, texts: Set<String>)] = await {
            var rows: [(String, Set<String>)] = []
            for interest in ["animals", "dinosaurs", "vehicles", "space", "sports", "robots"] {
                let cell = await library.cell(phoneme: "sh", interest: interest, ageBand: .mid)
                rows.append((interest, Set(cell?.sentences.map(\.text) ?? [])))
            }
            return rows
        }()

        let interestsHit = allMidCellTexts.filter { row in
            !row.texts.isDisjoint(with: union)
        }.map(\.interest)

        XCTAssertGreaterThanOrEqual(
            interestsHit.count, 2,
            "expected union to span ≥ 2 interest cells, got \(interestsHit)")
    }

    /// When `excluding` is small and pool is large, returned sentences must
    /// not overlap the excluded set.
    func test_sentences_excludingFilter_skipsExcluded() async throws {
        let library = try SentenceLibrary()
        let cell = await library.cell(phoneme: "sh", interest: "vehicles", ageBand: .mid)
        let texts = (cell?.sentences.map(\.text) ?? [])
        let excluded = Set(texts.prefix(15))  // exclude 15 of 20

        let result = await library.sentences(
            target: "sh_onset",
            interests: ["vehicles"],
            ageYears: 9,
            excluding: excluded,
            count: 3
        )

        XCTAssertEqual(result.count, 3)
        for sentence in result {
            XCTAssertFalse(
                excluded.contains(sentence.text),
                "sentence should have been filtered out: \(sentence.text)")
        }
    }

    /// When `excluding` is so large that the post-filter pool is below `count`,
    /// the selector relaxes the filter and samples from the full pool.
    func test_sentences_excludingTooLarge_relaxesFilter() async throws {
        let library = try SentenceLibrary()
        let cell = await library.cell(phoneme: "sh", interest: "vehicles", ageBand: .mid)
        let texts = (cell?.sentences.map(\.text) ?? [])
        // Exclude 19 of 20 — post-filter pool is 1, below count=3.
        let excluded = Set(texts.prefix(19))

        let result = await library.sentences(
            target: "sh_onset",
            interests: ["vehicles"],
            ageYears: 9,
            excluding: excluded,
            count: 3
        )

        XCTAssertEqual(result.count, 3)
        // Some of the returned sentences MUST come from the excluded set,
        // because the unexcluded pool only has 1 entry and we asked for 3.
        let returnedTexts = Set(result.map(\.text))
        XCTAssertGreaterThanOrEqual(
            returnedTexts.intersection(excluded).count, 2,
            "expected ≥ 2 of 3 returned sentences to come from the excluded set after relaxation")
    }

    /// When no cells exist for the target (e.g. `th` at this PR's HEAD), the
    /// selector returns `[]` so the caller can fall back to the per-week JSON.
    func test_sentences_noCellsForTarget_returnsEmpty() async throws {
        let library = try SentenceLibrary()

        let result = await library.sentences(
            target: "th_voiceless",
            interests: ["robots"],
            ageYears: 9,
            excluding: [],
            count: 3
        )

        XCTAssertTrue(result.isEmpty, "expected [] for target with no authored cells; got \(result.count)")
    }

    /// Unknown SkillCode (not in `directoryForSkillCode`) returns `[]`.
    func test_sentences_unknownSkillCode_returnsEmpty() async throws {
        let library = try SentenceLibrary()

        let result = await library.sentences(
            target: "not_a_real_skill",
            interests: ["vehicles"],
            ageYears: 9,
            excluding: [],
            count: 3
        )

        XCTAssertTrue(result.isEmpty, "expected [] for unknown SkillCode")
    }
}
