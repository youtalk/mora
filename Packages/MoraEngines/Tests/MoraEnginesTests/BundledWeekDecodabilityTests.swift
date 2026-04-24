// Packages/MoraEngines/Tests/MoraEnginesTests/BundledWeekDecodabilityTests.swift
import MoraCore
import XCTest

@testable import MoraEngines

final class BundledWeekDecodabilityTests: XCTestCase {
    func test_everyBundledWeek_decodeWords_useOnlyTaughtOrTargetGraphemes() throws {
        let codes: [SkillCode] = ["sh_onset", "th_voiceless", "f_onset", "r_onset", "short_a"]
        for code in codes {
            let provider = try ScriptedContentProvider.bundled(for: code)
            let allowed = provider.taughtGraphemes.union([provider.target])
            for dw in provider.words {
                for g in dw.word.graphemes {
                    XCTAssertTrue(
                        allowed.contains(g),
                        "\(code.rawValue): \(dw.word.surface) uses untaught grapheme \(g.letters)"
                    )
                }
            }
        }
    }

    func test_everyBundledWeek_sentences_wordsUseOnlyTaughtOrTargetGraphemes() throws {
        let codes: [SkillCode] = ["sh_onset", "th_voiceless", "f_onset", "r_onset", "short_a"]
        for code in codes {
            let provider = try ScriptedContentProvider.bundled(for: code)
            let allowed = provider.taughtGraphemes.union([provider.target])
            for sentence in provider.sentences {
                for w in sentence.words {
                    for g in w.graphemes {
                        XCTAssertTrue(
                            allowed.contains(g),
                            "\(code.rawValue) sentence: \(w.surface) uses untaught grapheme \(g.letters)"
                        )
                    }
                }
            }
        }
    }
}
