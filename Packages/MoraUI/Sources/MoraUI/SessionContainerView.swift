import MoraCore
import MoraEngines
import MoraTesting
import SwiftData
import SwiftUI

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
            let provider = try ScriptedContentProvider.bundledShWeek1()

            let request = ContentRequest(
                target: target.skill.graphemePhoneme!.grapheme,
                taughtGraphemes: taught,
                interests: [],
                count: 5
            )
            let words = try provider.decodeWords(request)
            let sentences = try provider.decodeSentences(
                ContentRequest(
                    target: request.target,
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
        try? context.save()
    }
}

// TEMPORARY stubs — replaced in Tasks 26 and 27.
struct WarmupView: View {
    let orchestrator: SessionOrchestrator
    var body: some View { Text("Warmup placeholder") }
}
struct NewRuleView: View {
    let orchestrator: SessionOrchestrator
    var body: some View { Text("New Rule placeholder") }
}
struct DecodeActivityView: View {
    let orchestrator: SessionOrchestrator
    var body: some View { Text("Decode placeholder") }
}
struct ShortSentencesView: View {
    let orchestrator: SessionOrchestrator
    var body: some View { Text("Sentences placeholder") }
}
struct CompletionView: View {
    let orchestrator: SessionOrchestrator
    let persistSummary: (SessionSummary) -> Void
    var body: some View { Text("Completion placeholder") }
}
