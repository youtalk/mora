// Packages/MoraEngines/Tests/MoraEnginesTests/SystematicPrincipleTests.swift
import MoraCore
import XCTest

@testable import MoraEngines

final class SystematicPrincipleTests: XCTestCase {
    func test_everyBundledWeek_decodeWords_useExactlyTheWeeksTargetPhoneme() throws {
        let ladder = CurriculumEngine.defaultV1Ladder()
        for skill in ladder.skills {
            guard let target = skill.graphemePhoneme else {
                XCTFail("\(skill.code.rawValue) missing graphemePhoneme")
                continue
            }
            let provider = try ScriptedContentProvider.bundled(for: skill.code)
            let request = ContentRequest(
                target: target.grapheme,
                taughtGraphemes: provider.taughtGraphemes,
                interests: [],
                count: 20
            )
            let words = try provider.decodeWords(request)
            XCTAssertFalse(
                words.isEmpty,
                "\(skill.code.rawValue) provider returned zero decode words"
            )
            for dw in words {
                XCTAssertTrue(
                    dw.word.phonemes.contains(target.phoneme),
                    "\(skill.code.rawValue): \(dw.word.surface) lacks target /\(target.phoneme.ipa)/"
                )
            }
        }
    }

    func test_everyBundledWeek_sentences_containAWordWithTargetGrapheme() throws {
        let ladder = CurriculumEngine.defaultV1Ladder()
        for skill in ladder.skills {
            guard let target = skill.graphemePhoneme else { continue }
            let provider = try ScriptedContentProvider.bundled(for: skill.code)
            let request = ContentRequest(
                target: target.grapheme,
                taughtGraphemes: provider.taughtGraphemes,
                interests: [],
                count: 10
            )
            let sentences = try provider.decodeSentences(request)
            XCTAssertFalse(sentences.isEmpty, "\(skill.code.rawValue) returned zero sentences")
            for s in sentences {
                XCTAssertTrue(
                    s.words.contains(where: { $0.graphemes.contains(target.grapheme) }),
                    "\(skill.code.rawValue) sentence '\(s.text)' lacks target grapheme '\(target.grapheme.letters)'"
                )
            }
        }
    }

    func test_everySkill_warmupCandidates_containTargetGrapheme() {
        let ladder = CurriculumEngine.defaultV1Ladder()
        for skill in ladder.skills {
            guard let target = skill.graphemePhoneme?.grapheme else { continue }
            XCTAssertTrue(
                skill.warmupCandidates.contains(target),
                "\(skill.code.rawValue) warmup candidates must contain \(target.letters)"
            )
        }
    }
}
