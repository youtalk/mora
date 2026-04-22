import MoraCore
import MoraEngines
import SwiftUI

struct DecodeActivityView: View {
    let orchestrator: SessionOrchestrator
    let uiMode: SessionUIMode
    @Binding var feedback: FeedbackState

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()
            if let current = currentWord {
                Text(current.word.surface)
                    .font(MoraType.decodingWord())
                    .foregroundStyle(MoraTheme.Ink.primary)

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
                    // PR 5 wires the real state machine. Until then the button
                    // is disabled with clear "coming soon" accessibility so
                    // VoiceOver doesn't promise recording behavior we haven't
                    // built yet.
                    MicButton(state: .idle, action: {})
                        .disabled(true)
                        .allowsHitTesting(false)
                        .accessibilityLabel("Recording unavailable")
                        .accessibilityHint("Microphone input lands in a later update.")
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
}
