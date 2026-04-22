import MoraCore
import MoraEngines
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

private enum MicUIState: Equatable {
    case idle
    case listening(partialText: String)
    case assessing
}

struct DecodeActivityView: View {
    let orchestrator: SessionOrchestrator
    let uiMode: SessionUIMode
    @Binding var feedback: FeedbackState
    let speechEngine: SpeechEngine?
    let ttsEngine: TTSEngine?

    @State private var micState: MicUIState = .idle
    @State private var shakeAmount: CGFloat = 0

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()
            if let current = currentWord {
                Text(current.word.surface)
                    .font(MoraType.decodingWord())
                    .foregroundStyle(MoraTheme.Ink.primary)
                    .shake(amount: shakeAmount)
                    .onLongPressGesture {
                        guard let tts = ttsEngine else { return }
                        Task { await tts.speak(current.word.surface) }
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

                Text(
                    "Word \(orchestrator.wordIndex + 1) of \(orchestrator.words.count)"
                )
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)
                .padding(.bottom, MoraTheme.Space.lg)
            } else {
                ProgressView()
            }
        }
        .onChange(of: feedback) { _, new in
            if new == .wrong {
                withAnimation(.linear(duration: 0.6)) { shakeAmount = 1 }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 600_000_000)
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
            MicButton(state: micButtonState) {
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

    private var micButtonState: MicButtonState {
        switch micState {
        case .idle: return .idle
        case .listening: return .listening
        case .assessing: return .assessing
        }
    }

    private var currentWord: DecodeWord? {
        guard orchestrator.wordIndex < orchestrator.words.count else { return nil }
        return orchestrator.words[orchestrator.wordIndex]
    }

    private func tapPair(word: Word) -> some View {
        HStack(spacing: MoraTheme.Space.xl) {
            tapButton("Correct", color: MoraTheme.Feedback.correct) {
                feedback = .correct
                Task { @MainActor in
                    await orchestrator.handle(.answerManual(correct: true))
                    try? await Task.sleep(nanoseconds: 450_000_000)
                    feedback = .none
                }
            }
            tapButton("Wrong", color: MoraTheme.Feedback.wrong) {
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
                        if !wasCorrect, let tts = ttsEngine {
                            await tts.speak("Listen: " + expected.surface)
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
