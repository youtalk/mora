import MoraCore
import MoraEngines
import SwiftUI

struct ShortSentencesView: View {
    let orchestrator: SessionOrchestrator

    var body: some View {
        VStack(spacing: 24) {
            Text("Read the sentence")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            if let current = currentSentence {
                Text(current.text)
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding()
                HStack(spacing: 40) {
                    sentenceButton("Correct", color: .green) {
                        Task {
                            await orchestrator.handle(
                                .answerResult(
                                    correct: true,
                                    asr: ASRResult(
                                        transcript: current.text,
                                        confidence: 1.0
                                    )
                                )
                            )
                        }
                    }
                    sentenceButton("Wrong", color: .orange) {
                        Task {
                            await orchestrator.handle(
                                .answerResult(
                                    correct: false,
                                    asr: ASRResult(transcript: "", confidence: 0.0)
                                )
                            )
                        }
                    }
                }
                Text(
                    "Sentence \(orchestrator.sentenceIndex + 1) of \(orchestrator.sentences.count)"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .padding()
    }

    private var currentSentence: DecodeSentence? {
        guard orchestrator.sentenceIndex < orchestrator.sentences.count else { return nil }
        return orchestrator.sentences[orchestrator.sentenceIndex]
    }

    private func sentenceButton(
        _ title: String, color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.semibold))
                .frame(minWidth: 160, minHeight: 60)
                .background(color, in: .capsule)
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}
