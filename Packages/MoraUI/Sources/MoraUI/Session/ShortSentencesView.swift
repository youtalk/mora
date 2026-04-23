import MoraCore
import MoraEngines
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct ShortSentencesView: View {
    @Environment(\.moraStrings) private var strings
    let orchestrator: SessionOrchestrator
    let uiMode: SessionUIMode
    @Binding var feedback: FeedbackState
    let speechEngine: SpeechEngine?
    let ttsEngine: TTSEngine?

    @State private var micState: MicUIState = .idle
    @State private var shakeAmount: CGFloat = 0
    @State private var shakeResetTask: Task<Void, Never>?
    /// Pin the on-screen sentence to a specific orchestrator index during
    /// feedback / corrective audio — same reason as DecodeActivityView:
    /// without it, `orchestrator.handle(.answerHeard)` advances
    /// `sentenceIndex` immediately, the body re-renders the next sentence,
    /// and the "Listen:" audio then names the previous sentence.
    @State private var pinnedSentenceIndex: Int?
    @State private var lastHeard: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: MoraTheme.Space.lg) {
                if let current = displayedSentence {
                    Text(current.text)
                        .font(MoraType.sentence())
                        .foregroundStyle(MoraTheme.Ink.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, MoraTheme.Space.xl)
                        .minimumScaleFactor(0.5)
                        .shake(amount: shakeAmount)
                        .onLongPressGesture {
                            guard let tts = ttsEngine else { return }
                            Task { await tts.speak(current.text, pace: .slow) }
                        }

                    switch uiMode {
                    case .tap:
                        tapPair(sentence: current)
                    case .mic:
                        micStack
                    }

                    VStack(spacing: MoraTheme.Space.xs) {
                        Text(
                            strings.sessionSentenceCounter(
                                orchestrator.sentenceIndex + 1, orchestrator.sentences.count
                            )
                        )
                        Text(strings.sentencesLongPressHint)
                            .multilineTextAlignment(.center)
                    }
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Ink.muted)
                    .minimumScaleFactor(0.5)
                } else {
                    ProgressView()
                }
            }
            .padding(.vertical, MoraTheme.Space.xl)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: feedback) { _, new in
            if new == .wrong {
                // Cancel any in-flight reset so back-to-back .wrong events
                // don't race.
                shakeResetTask?.cancel()
                withAnimation(.linear(duration: 0.6)) { shakeAmount = 1 }
                shakeResetTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    guard !Task.isCancelled else { return }
                    shakeAmount = 0
                }
            }
            #if canImport(UIKit)
            switch new {
            case .correct: UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .wrong: UINotificationFeedbackGenerator().notificationOccurred(.error)
            case .none: break
            }
            #endif
        }
    }

    private var micStack: some View {
        VStack(spacing: MoraTheme.Space.md) {
            MicButton(state: micState.buttonState) {
                switch micState {
                case .idle:
                    if let engine = speechEngine { startListening(engine: engine) }
                case .listening:
                    speechEngine?.cancel()
                case .assessing:
                    break
                }
            }
            transcriptLine
        }
    }

    @ViewBuilder
    private var transcriptLine: some View {
        if case .listening(let partial) = micState, !partial.isEmpty {
            Text(partial)
                .font(MoraType.transcript())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.center)
        } else if !lastHeard.isEmpty {
            Text(lastHeard)
                .font(MoraType.transcript())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.center)
        }
    }

    private var displayedSentence: DecodeSentence? {
        let idx = pinnedSentenceIndex ?? orchestrator.sentenceIndex
        guard idx < orchestrator.sentences.count else { return nil }
        return orchestrator.sentences[idx]
    }

    private func tapPair(sentence: DecodeSentence) -> some View {
        HStack(spacing: MoraTheme.Space.xl) {
            tapButton(strings.feedbackCorrect, color: MoraTheme.Feedback.correct) {
                feedback = .correct
                Task { @MainActor in
                    let priorIndex = orchestrator.sentenceIndex
                    pinnedSentenceIndex = priorIndex
                    await orchestrator.handle(.answerManual(correct: true))
                    try? await Task.sleep(nanoseconds: 450_000_000)
                    feedback = .none
                    pinnedSentenceIndex = nil
                }
            }
            tapButton(strings.feedbackTryAgain, color: MoraTheme.Feedback.wrong) {
                feedback = .wrong
                Task { @MainActor in
                    let priorIndex = orchestrator.sentenceIndex
                    pinnedSentenceIndex = priorIndex
                    await orchestrator.handle(.answerManual(correct: false))
                    try? await Task.sleep(nanoseconds: 650_000_000)
                    feedback = .none
                    pinnedSentenceIndex = nil
                }
            }
        }
    }

    private func tapButton(
        _ title: String, color: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(MoraType.heading())
                .foregroundStyle(.white)
                .frame(minWidth: 200, minHeight: 72)
                .background(color, in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private func startListening(engine: SpeechEngine) {
        guard let expected = displayedSentence else { return }
        lastHeard = ""
        micState = .listening(partialText: "")
        Task { @MainActor in
            defer {
                // Stream may terminate without a .final event (cancel, early
                // return). Always return to .idle so the MicButton doesn't
                // stay stuck in .listening/.assessing.
                if micState != .idle { micState = .idle }
            }
            do {
                for try await event in engine.listen() {
                    switch event {
                    case .started:
                        break
                    case .partial(let text):
                        if case .listening = micState {
                            micState = .listening(partialText: text)
                        }
                    case .final(let asr):
                        let priorIndex = orchestrator.sentenceIndex
                        pinnedSentenceIndex = priorIndex
                        lastHeard = asr.transcript
                        micState = .assessing
                        try? await Task.sleep(nanoseconds: 120_000_000)
                        await orchestrator.handle(.answerHeard(asr))
                        let wasCorrect = orchestrator.trials.last?.correct ?? false
                        feedback = wasCorrect ? .correct : .wrong
                        if !wasCorrect, let tts = ttsEngine {
                            await tts.speak("Listen: " + expected.text, pace: .slow)
                        }
                        try? await Task.sleep(
                            nanoseconds: wasCorrect ? 450_000_000 : 650_000_000)
                        feedback = .none
                        micState = .idle
                        pinnedSentenceIndex = nil
                        lastHeard = ""
                    }
                }
            } catch {
                micState = .idle
            }
        }
    }
}
