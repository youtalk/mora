import MoraCore
import MoraEngines
import SwiftUI

struct DecodeActivityView: View {
    let orchestrator: SessionOrchestrator

    var body: some View {
        VStack(spacing: 24) {
            Text("Read the word")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            if let current = currentWord {
                Text(current.word.surface)
                    .font(.system(size: 96, weight: .heavy, design: .rounded))
                    .padding(.vertical, 24)
                if let note = current.note {
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 40) {
                    decodeButton("Correct", color: .green) {
                        Task {
                            await orchestrator.handle(
                                .answerResult(
                                    correct: true,
                                    asr: ASRResult(
                                        transcript: current.word.surface,
                                        confidence: 1.0
                                    )
                                )
                            )
                        }
                    }
                    decodeButton("Wrong", color: .orange) {
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
                Text("Progress: \(orchestrator.wordIndex + 1) of \(orchestrator.words.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .padding()
    }

    private var currentWord: DecodeWord? {
        guard orchestrator.wordIndex < orchestrator.words.count else { return nil }
        return orchestrator.words[orchestrator.wordIndex]
    }

    private func decodeButton(
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
