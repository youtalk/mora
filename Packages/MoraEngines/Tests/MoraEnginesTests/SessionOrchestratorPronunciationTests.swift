import MoraCore
import XCTest

@testable import MoraEngines

@MainActor
final class SessionOrchestratorPronunciationTests: XCTestCase {

    func testDecodingRecordsPhonemeTrialAssessmentFromEvaluator() async {
        let fake = ScriptedPronunciationEvaluator()
        fake.supportedTargets = ["ʃ"]
        fake.responses["ʃ"] = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "ʃ"),
            label: .substitutedBy(Phoneme(ipa: "s")),
            score: 28,
            coachingKey: "coaching.sh_sub_s",
            features: [:],
            isReliable: true
        )
        let engine = AssessmentEngine(l1Profile: JapaneseL1Profile(), evaluator: fake)
        let word = Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")],
            targetPhoneme: Phoneme(ipa: "ʃ")
        )
        let orchestrator = SessionOrchestrator(
            target: Target.dummyForShipTests(),
            taughtGraphemes: [],
            warmupOptions: [],
            words: [DecodeWord(word: word)],
            sentences: [],
            assessment: engine
        )
        await orchestrator.start()
        // Skip past warmup and newRule via the existing orchestrator API.
        await orchestrator.advanceToDecodingForTests()

        let recording = TrialRecording(
            asr: ASRResult(transcript: "sip", confidence: 0.85),
            audio: .empty
        )
        await orchestrator.handle(.answerHeard(recording))

        XCTAssertEqual(orchestrator.trials.count, 1)
        XCTAssertEqual(orchestrator.trials.first?.phoneme?.score, 28)
    }
}

extension Target {
    static func dummyForShipTests() -> Target {
        let skill = Skill(
            code: "sh_onset", level: .l3, displayName: "sh",
            graphemePhoneme: .init(
                grapheme: .init(letters: "sh"),
                phoneme: .init(ipa: "ʃ")
            )
        )
        return Target(weekStart: Date(), skill: skill)
    }
}

extension SessionOrchestrator {
    func advanceToDecodingForTests() async {
        if let g = target.skill.graphemePhoneme?.grapheme {
            await handle(.warmupTap(g))
        }
        await handle(.advance)
    }
}
