import MoraCore
import MoraEngines
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct DecodeActivityView: View {
    @Environment(\.moraStrings) private var strings
    let orchestrator: SessionOrchestrator
    let uiMode: SessionUIMode
    @Binding var feedback: FeedbackState
    let speechEngine: SpeechEngine?
    let speech: SpeechController?

    @State private var micState: MicUIState = .idle
    @State private var shakeAmount: CGFloat = 0
    @State private var shakeResetTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()
            if let current = currentWord {
                Text(current.word.surface)
                    .font(MoraType.decodingWord())
                    .foregroundStyle(MoraTheme.Ink.primary)
                    .shake(amount: shakeAmount)
                    .onLongPressGesture {
                        speech?.play([.text(current.word.surface)])
                    }

                if let note = current.note {
                    Text(note)
                        .font(MoraType.label())
                        .foregroundStyle(MoraTheme.Ink.muted)
                }

                Spacer()

                switch uiMode {
                case .tap:
                    tapPair(word: current.word)
                case .mic:
                    micStack
                }

                HStack(spacing: MoraTheme.Space.sm) {
                    Text(
                        strings.sessionWordCounter(
                            orchestrator.wordIndex + 1, orchestrator.words.count
                        )
                    )
                    Text("·")
                    Text(strings.decodingLongPressHint)
                }
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)
                .padding(.bottom, MoraTheme.Space.lg)
            } else {
                ProgressView()
            }
        }
        .onChange(of: feedback) { _, new in
            if new == .wrong {
                // Cancel any in-flight reset so back-to-back .wrong events
                // don't race (older task would clear shakeAmount mid-shake).
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
        VStack(spacing: MoraTheme.Space.sm) {
            MicButton(state: micState.buttonState) {
                switch micState {
                case .idle:
                    if let engine = speechEngine { startListening(engine: engine) }
                case .listening:
                    // Match MicButton's "Tap to stop recording" hint: cancel
                    // the engine so the consumer's for-try-await loop exits
                    // via onTermination and the state machine resets.
                    speechEngine?.cancel()
                case .assessing:
                    break
                }
            }
            if case .listening(let text) = micState, !text.isEmpty {
                Text(text)
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Ink.muted)
            }
        }
    }

    private var currentWord: DecodeWord? {
        guard orchestrator.wordIndex < orchestrator.words.count else { return nil }
        return orchestrator.words[orchestrator.wordIndex]
    }

    private func tapPair(word: Word) -> some View {
        HStack(spacing: MoraTheme.Space.xl) {
            tapButton(strings.feedbackCorrect, color: MoraTheme.Feedback.correct) {
                feedback = .correct
                Task { @MainActor in
                    await orchestrator.handle(.answerManual(correct: true))
                    try? await Task.sleep(nanoseconds: 450_000_000)
                    feedback = .none
                }
            }
            tapButton(strings.feedbackTryAgain, color: MoraTheme.Feedback.wrong) {
                feedback = .wrong
                Task { @MainActor in
                    await orchestrator.handle(.answerManual(correct: false))
                    try? await Task.sleep(nanoseconds: 650_000_000)
                    feedback = .none
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
        guard let expected = currentWord?.word else { return }
        micState = .listening(partialText: "")
        Task { @MainActor in
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
                        micState = .assessing
                        try? await Task.sleep(nanoseconds: 120_000_000)
                        await orchestrator.handle(.answerHeard(asr))
                        let wasCorrect = orchestrator.trials.last?.correct ?? false
                        feedback = wasCorrect ? .correct : .wrong
                        if !wasCorrect, let speech {
                            // Awaiting the corrective utterance keeps the
                            // on-screen state stable until it finishes. The
                            // controller cancels this sequence if the session
                            // advances phase or the close button fires before
                            // the line finishes playing.
                            await speech.playAndAwait(
                                [.text("Listen: " + expected.surface)]
                            )
                        }
                        try? await Task.sleep(
                            nanoseconds: wasCorrect ? 450_000_000 : 650_000_000)
                        feedback = .none
                        micState = .idle
                    }
                }
            } catch {
                micState = .idle
            }
        }
    }
}
