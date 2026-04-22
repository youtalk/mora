import MoraCore
import MoraEngines
import SwiftUI

private enum SentenceMicUIState: Equatable {
    case idle
    case listening(partialText: String)
    case assessing
}

struct ShortSentencesView: View {
    let orchestrator: SessionOrchestrator
    let uiMode: SessionUIMode
    @Binding var feedback: FeedbackState
    let speechEngine: SpeechEngine?
    let ttsEngine: TTSEngine?

    @State private var micState: SentenceMicUIState = .idle

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()
            if let current = currentSentence {
                Text(current.text)
                    .font(MoraType.sentence())
                    .foregroundStyle(MoraTheme.Ink.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, MoraTheme.Space.xl)
                    .onLongPressGesture {
                        guard let tts = ttsEngine else { return }
                        Task { await tts.speak(current.text) }
                    }

                Spacer()

                switch uiMode {
                case .tap:
                    tapPair(sentence: current)
                case .mic:
                    micStack
                }

                Text(
                    "Sentence \(orchestrator.sentenceIndex + 1) of \(orchestrator.sentences.count)"
                )
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)
                .padding(.bottom, MoraTheme.Space.lg)
            } else {
                ProgressView()
            }
        }
    }

    private var micStack: some View {
        VStack(spacing: MoraTheme.Space.sm) {
            MicButton(state: micButtonState) {
                switch micState {
                case .idle:
                    if let engine = speechEngine { startListening(engine: engine) }
                case .listening:
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

    private var currentSentence: DecodeSentence? {
        guard orchestrator.sentenceIndex < orchestrator.sentences.count else { return nil }
        return orchestrator.sentences[orchestrator.sentenceIndex]
    }

    private func tapPair(sentence: DecodeSentence) -> some View {
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
        guard let expected = currentSentence else { return }
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
                        micState = .assessing
                        try? await Task.sleep(nanoseconds: 120_000_000)
                        await orchestrator.handle(.answerHeard(asr))
                        let wasCorrect = orchestrator.trials.last?.correct ?? false
                        feedback = wasCorrect ? .correct : .wrong
                        if !wasCorrect, let tts = ttsEngine {
                            await tts.speak("Listen: " + expected.text)
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
