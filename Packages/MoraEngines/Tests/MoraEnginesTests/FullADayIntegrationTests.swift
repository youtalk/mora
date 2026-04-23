import MoraCore
import XCTest

@testable import MoraEngines

/// End-to-end integration coverage for an A-day session: curriculum → content
/// provider → orchestrator → summary. Unlike the per-phase orchestrator tests,
/// this wires the real `CurriculumEngine.defaultV1Ladder()`, the bundled
/// `sh_week1.json` content, and a real `AssessmentEngine`, so a regression in
/// any one of those layers shows up here.
@MainActor
final class FullADayIntegrationTests: XCTestCase {
    func test_fullADay_walkthroughEndsInCompletionAndCorrectSummary() async throws {
        let curriculum = CurriculumEngine.defaultV1Ladder()
        let target = curriculum.currentTarget(forWeekIndex: 0)
        let taught = curriculum.taughtGraphemes(beforeWeekIndex: 0)
        let provider = try ScriptedContentProvider.bundledShWeek1()
        let targetGrapheme = try XCTUnwrap(
            target.skill.graphemePhoneme?.grapheme,
            "Expected week 0 curriculum target to provide a grapheme/phoneme mapping for scripted content."
        )

        let request = ContentRequest(
            target: targetGrapheme,
            taughtGraphemes: taught,
            interests: [],
            count: 5
        )
        let words = try provider.decodeWords(request)
        let sentences = try provider.decodeSentences(
            ContentRequest(
                target: request.target,
                taughtGraphemes: taught,
                interests: [],
                count: 2
            )
        )
        XCTAssertEqual(words.count, 5)
        XCTAssertEqual(sentences.count, 2)

        // The clock is pinned to the epoch start and the end timestamp is
        // supplied explicitly, so the asserted duration is computed against a
        // fixed pair of timestamps rather than wall-clock drift.
        let fakeStart = Date(timeIntervalSince1970: 0)
        let orchestrator = SessionOrchestrator(
            target: target,
            taughtGraphemes: taught,
            warmupOptions: [
                Grapheme(letters: "s"),
                Grapheme(letters: "sh"),
                Grapheme(letters: "ch"),
            ],
            words: words,
            sentences: sentences,
            assessment: AssessmentEngine(l1Profile: JapaneseL1Profile()),
            clock: { fakeStart }
        )

        await orchestrator.start()
        XCTAssertEqual(orchestrator.phase, .warmup)

        await orchestrator.handle(.warmupTap(Grapheme(letters: "sh")))
        XCTAssertEqual(orchestrator.phase, .newRule)

        await orchestrator.handle(.advance)
        XCTAssertEqual(orchestrator.phase, .decoding)

        for w in words {
            await orchestrator.handle(
                .answerHeard(
                    TrialRecording(
                        asr: ASRResult(transcript: w.word.surface, confidence: 1.0),
                        audio: .empty
                    )
                )
            )
        }
        XCTAssertEqual(orchestrator.phase, .shortSentences)

        // Sentences target a single word inside the sentence text, so an ASR
        // transcript of the whole sentence would not match. Use the manual
        // path to keep this walkthrough's intent of "all sentences correct"
        // without replicating the orchestrator's target-word selection here.
        for _ in sentences {
            await orchestrator.handle(.answerManual(correct: true))
        }
        XCTAssertEqual(orchestrator.phase, .completion)

        let summary = orchestrator.sessionSummary(
            endedAt: Date(timeInterval: 900, since: fakeStart)
        )
        XCTAssertEqual(summary.sessionType, .coreDecoder)
        XCTAssertEqual(summary.targetSkillCode, "sh_onset")
        XCTAssertEqual(summary.trialsTotal, words.count + sentences.count)
        XCTAssertEqual(summary.trialsCorrect, words.count + sentences.count)
        XCTAssertEqual(summary.durationSec, 900)
        XCTAssertFalse(summary.escalated)
        XCTAssertTrue(summary.struggledSkillCodes.isEmpty)
    }

    func test_fullADay_withOneMiss_reportsStruggledSkill() async throws {
        let curriculum = CurriculumEngine.defaultV1Ladder()
        let target = curriculum.currentTarget(forWeekIndex: 0)
        let taught = curriculum.taughtGraphemes(beforeWeekIndex: 0)
        let provider = try ScriptedContentProvider.bundledShWeek1()
        let targetGrapheme = try XCTUnwrap(
            target.skill.graphemePhoneme?.grapheme,
            "Expected week 0 curriculum target to provide a grapheme/phoneme mapping for scripted content."
        )
        let words = try provider.decodeWords(
            ContentRequest(
                target: targetGrapheme,
                taughtGraphemes: taught,
                interests: [],
                count: 5
            )
        )
        let sentences = try provider.decodeSentences(
            ContentRequest(
                target: targetGrapheme,
                taughtGraphemes: taught,
                interests: [],
                count: 2
            )
        )
        let missIndex = 2

        let orchestrator = SessionOrchestrator(
            target: target,
            taughtGraphemes: taught,
            warmupOptions: [Grapheme(letters: "sh")],
            words: words,
            sentences: sentences,
            assessment: AssessmentEngine(l1Profile: JapaneseL1Profile()),
            clock: { Date(timeIntervalSince1970: 0) }
        )
        await orchestrator.start()
        await orchestrator.handle(.warmupTap(Grapheme(letters: "sh")))
        await orchestrator.handle(.advance)

        for (i, w) in words.enumerated() {
            let correct = i != missIndex
            if correct {
                await orchestrator.handle(
                    .answerHeard(
                        TrialRecording(
                            asr: ASRResult(transcript: w.word.surface, confidence: 1.0),
                            audio: .empty
                        )
                    )
                )
            } else {
                await orchestrator.handle(.answerManual(correct: false))
            }
        }
        for _ in sentences {
            await orchestrator.handle(.answerManual(correct: true))
        }

        XCTAssertEqual(orchestrator.phase, .completion)

        // The miss at `missIndex` must have been routed through
        // `AssessmentEngine`, which classifies an empty transcript as
        // `.omission` and echoes the transcript into `heard`. Asserting on
        // `orchestrator.trials` (instead of only the summary) guards against
        // a regression where the orchestrator stopped invoking the
        // AssessmentEngine on misses — that regression would still produce a
        // correct summary count but would silently lose the error taxonomy.
        XCTAssertEqual(orchestrator.trials.count, words.count + sentences.count)
        let missedTrial = orchestrator.trials[missIndex]
        XCTAssertFalse(missedTrial.correct)
        XCTAssertEqual(missedTrial.errorKind, .omission)
        XCTAssertEqual(missedTrial.heard, "")
        XCTAssertEqual(missedTrial.expected.surface, words[missIndex].word.surface)

        let summary = orchestrator.sessionSummary(endedAt: Date(timeIntervalSince1970: 600))
        XCTAssertEqual(summary.trialsCorrect, summary.trialsTotal - 1)
        XCTAssertEqual(summary.struggledSkillCodes, [SkillCode("sh_onset")])
    }
}
