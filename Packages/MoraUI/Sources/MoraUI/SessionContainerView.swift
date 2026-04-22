import MoraCore
import MoraEngines
import OSLog
import SwiftData
import SwiftUI

private let persistLog = Logger(subsystem: "tech.reenable.Mora", category: "Persistence")

public struct SessionContainerView: View {
    @Environment(\.modelContext) private var context
    @State private var orchestrator: SessionOrchestrator?
    @State private var bootError: String?

    public init() {}

    public var body: some View {
        Group {
            if let orchestrator {
                switch orchestrator.phase {
                case .notStarted:
                    ProgressView("Preparing…")
                        .task { await orchestrator.start() }
                case .warmup:
                    WarmupView(orchestrator: orchestrator)
                case .newRule:
                    NewRuleView(orchestrator: orchestrator)
                case .decoding:
                    DecodeActivityView(orchestrator: orchestrator)
                case .shortSentences:
                    ShortSentencesView(orchestrator: orchestrator)
                case .completion:
                    CompletionView(
                        orchestrator: orchestrator,
                        persistSummary: { summary in
                            persist(summary: summary)
                        }
                    )
                }
            } else if let bootError {
                Text("Could not start session: \(bootError)")
            } else {
                ProgressView("Loading session…")
                    .task { await bootstrap() }
            }
        }
        .background(Color(red: 0.98, green: 0.96, blue: 0.90))
    }

    @MainActor
    private func bootstrap() async {
        do {
            let curriculum = CurriculumEngine.defaultV1Ladder()
            let target = curriculum.currentTarget(forWeekIndex: 0)
            let taught = curriculum.taughtGraphemes(beforeWeekIndex: 0)
            guard let targetGrapheme = target.skill.graphemePhoneme?.grapheme else {
                bootError = "Target skill \(target.skill.code.rawValue) has no grapheme/phoneme mapping"
                return
            }

            let provider = try ScriptedContentProvider.bundledShWeek1()
            let request = ContentRequest(
                target: targetGrapheme,
                taughtGraphemes: taught,
                interests: [],
                count: 5
            )
            let words = try provider.decodeWords(request)
            let sentences = try provider.decodeSentences(
                ContentRequest(
                    target: targetGrapheme,
                    taughtGraphemes: taught,
                    interests: [], count: 2
                )
            )

            self.orchestrator = SessionOrchestrator(
                target: target,
                taughtGraphemes: taught,
                warmupOptions: [
                    Grapheme(letters: "s"),
                    Grapheme(letters: "sh"),
                    Grapheme(letters: "ch"),
                ],
                words: words,
                sentences: sentences,
                assessment: AssessmentEngine(l1Profile: JapaneseL1Profile())
            )
        } catch {
            bootError = String(describing: error)
        }
    }

    @MainActor
    private func persist(summary: SessionSummary) {
        let entity = SessionSummaryEntity(
            date: Date(),
            sessionType: summary.sessionType.rawValue,
            targetSkillCode: summary.targetSkillCode.rawValue,
            durationSec: summary.durationSec,
            trialsTotal: summary.trialsTotal,
            trialsCorrect: summary.trialsCorrect,
            escalated: summary.escalated
        )
        context.insert(entity)
        do {
            try context.save()
        } catch {
            // Best-effort: a save failure here means the session log is lost
            // for this run, but the in-memory orchestrator state still
            // reflects what the learner just did. Surface to Console so the
            // failure is debuggable; do not crash the celebration screen.
            persistLog.error("SessionSummary save failed: \(error)")
        }
    }
}
