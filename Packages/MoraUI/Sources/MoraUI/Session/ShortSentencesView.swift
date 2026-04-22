import MoraCore
import MoraEngines
import SwiftUI

struct ShortSentencesView: View {
    let orchestrator: SessionOrchestrator
    let uiMode: SessionUIMode
    @Binding var feedback: FeedbackState

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()
            if let current = currentSentence {
                Text(current.text)
                    .font(MoraType.sentence())
                    .foregroundStyle(MoraTheme.Ink.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, MoraTheme.Space.xl)

                Spacer()

                switch uiMode {
                case .tap:
                    tapPair(sentence: current)
                case .mic:
                    MicButton(state: .idle, action: {})
                        .disabled(true)
                        .allowsHitTesting(false)
                        .accessibilityLabel("Recording unavailable")
                        .accessibilityHint("Microphone input lands in a later update.")
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
}
