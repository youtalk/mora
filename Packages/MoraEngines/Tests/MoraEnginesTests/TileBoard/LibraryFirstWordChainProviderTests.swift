import XCTest
import MoraCore
@testable import MoraEngines

final class LibraryFirstWordChainProviderTests: XCTestCase {
    private func g(_ s: String) -> Grapheme { Grapheme(letters: s) }

    /// The L2 alphabet is the baseline set every learner starts with; mirrors
    /// `CurriculumEngine.defaultV1Ladder()`'s `baselineTaughtGraphemes`.
    private static let alphabet: Set<Grapheme> = Set(
        "abcdefghijklmnopqrstuvwxyz".map { Grapheme(letters: String($0)) }
    )

    func testGenerateShPhaseFromBundledLibrary() throws {
        let inv = Self.alphabet.union([g("sh")])
        let provider = LibraryFirstWordChainProvider()
        let phase = try provider.generatePhase(target: g("sh"), masteredSet: inv)
        XCTAssertEqual(phase.count, 3)
        XCTAssertEqual(phase[0].role, .warmup)
        XCTAssertEqual(phase[1].role, .targetIntro)
        XCTAssertEqual(phase[2].role, .mixedApplication)
        XCTAssertEqual(phase[0].allWords.first?.surface, "cat")
        XCTAssertEqual(phase[1].allWords.first?.surface, "ship")
        XCTAssertEqual(phase[2].allWords.first?.surface, "fish")
    }

    /// Locks in that every curriculum phoneme has a bundled chain library
    /// that loads cleanly under the inventory the orchestrator will hand it.
    /// Regression guard for the bug where only sh.json existed and every
    /// other phoneme silently skipped the tile-board phase.
    func testEveryCurriculumSkillLoadsThreeValidChains() throws {
        let ladder = CurriculumEngine.sharedV1
        let provider = LibraryFirstWordChainProvider()
        for (index, skill) in ladder.skills.enumerated() {
            guard let target = skill.graphemePhoneme?.grapheme else {
                XCTFail("skill \(skill.code.rawValue) has no grapheme/phoneme mapping")
                continue
            }
            let mastered = ladder.taughtGraphemes(beforeWeekIndex: index)
            do {
                let phase = try provider.generatePhase(target: target, masteredSet: mastered)
                XCTAssertEqual(
                    phase.count, 3,
                    "skill \(skill.code.rawValue) must yield three chains")
                XCTAssertEqual(phase.map(\.role), [.warmup, .targetIntro, .mixedApplication])
            } catch {
                XCTFail(
                    "skill \(skill.code.rawValue) (target '\(target.letters)') failed to load: \(error)"
                )
            }
        }
    }

    /// Spec §6: at least 6 of 12 words in a phase must contain the target
    /// grapheme. Authored content must respect this so the learner sees the
    /// week's target a meaningful number of times.
    func testEveryCurriculumPhaseHitsTargetCoverageThreshold() throws {
        let ladder = CurriculumEngine.sharedV1
        let provider = LibraryFirstWordChainProvider()
        for (index, skill) in ladder.skills.enumerated() {
            guard let target = skill.graphemePhoneme?.grapheme else { continue }
            let mastered = ladder.taughtGraphemes(beforeWeekIndex: index)
            let phase = try provider.generatePhase(target: target, masteredSet: mastered)
            let allWords = phase.flatMap(\.allWords)
            let hits = allWords.filter { $0.graphemes.contains(target) }.count
            XCTAssertGreaterThanOrEqual(
                hits, 6,
                "skill \(skill.code.rawValue) target coverage is \(hits)/12, must be ≥ 6")
        }
    }

    /// Spec §7: a word may not appear in more than one chain within a phase.
    func testEveryCurriculumPhaseHasNoCrossChainWordRepetition() throws {
        let ladder = CurriculumEngine.sharedV1
        let provider = LibraryFirstWordChainProvider()
        for (index, skill) in ladder.skills.enumerated() {
            guard let target = skill.graphemePhoneme?.grapheme else { continue }
            let mastered = ladder.taughtGraphemes(beforeWeekIndex: index)
            let phase = try provider.generatePhase(target: target, masteredSet: mastered)
            let surfaces = phase.flatMap(\.allWords).map(\.surface)
            XCTAssertEqual(
                Set(surfaces).count, surfaces.count,
                "skill \(skill.code.rawValue) repeats a word across chains: \(surfaces)")
        }
    }

    func testMissingLibraryThrows() {
        let provider = LibraryFirstWordChainProvider()
        XCTAssertThrowsError(
            try provider.generatePhase(
                target: g("zz"),
                masteredSet: [g("zz")]
            ))
    }
}
