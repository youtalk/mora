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
    /// Pin the word shown on screen to a specific orchestrator index during
    /// the feedback / corrective-audio window. Without this, the orchestrator
    /// advances `wordIndex` the instant `.answerHeard` is handled and the
    /// body re-renders the NEXT word — while the TTS "Listen: ship" is still
    /// playing. Learners then see "shop" while hearing "ship", and stay one
    /// word off-screen for the rest of the session. `nil` = follow the
    /// orchestrator's live index.
    @State private var pinnedWordIndex: Int?
    /// ASR transcript to keep visible after `.final` so the learner (and the
    /// parent watching) can see what was heard, not just green/red feedback.
    @State private var lastHeard: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: MoraTheme.Space.lg) {
                if let current = displayedWord {
                    Text(current.word.surface)
                        .font(MoraType.decodingWord())
                        .foregroundStyle(MoraTheme.Ink.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .shake(amount: shakeAmount)
                        .onLongPressGesture {
                            speech?.play([.text(current.word.surface, .slow)])
                        }

                    if let note = current.note {
                        Text(note)
                            .font(MoraType.label())
                            .foregroundStyle(MoraTheme.Ink.muted)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.5)
                    }

                    switch uiMode {
                    case .tap:
                        tapPair(word: current.word)
                    case .mic:
                        micStack
                    }

                    VStack(spacing: MoraTheme.Space.xs) {
                        Text(
                            strings.sessionWordCounter(
                                (pinnedWordIndex ?? orchestrator.wordIndex) + 1,
                                orchestrator.words.count
                            )
                        )
                        Text(strings.decodingLongPressHint)
                            .multilineTextAlignment(.center)
                    }
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Ink.muted)
                    .minimumScaleFactor(0.5)

                    if let last = orchestrator.trials.last,
                        let phoneme = last.phoneme
                    {
                        PronunciationFeedbackOverlay(
                            viewModel: PronunciationFeedbackViewModel(
                                assessment: phoneme,
                                strings: strings
                            ),
                            onAppearSpeak: { [weak speech] text in
                                await speech?.playAndAwait([.text(text, .normal)])
                            }
                        )
                        .transition(.opacity.combined(with: .scale))
                        .padding(.top, MoraTheme.Space.md)
                    }
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
        VStack(spacing: MoraTheme.Space.md) {
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
            transcriptLine
        }
    }

    /// Shows the ASR transcript at a readable size whenever there is a
    /// partial or final transcript worth displaying. Keeps the heard word
    /// visible through the assessing / feedback window so the learner can
    /// compare expected vs. heard without squinting at 14-pt chrome.
    @ViewBuilder
    private var transcriptLine: some View {
        if case .listening(let partial) = micState, !partial.isEmpty {
            Text(partial)
                .font(MoraType.transcript())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        } else if !lastHeard.isEmpty {
            Text(lastHeard)
                .font(MoraType.transcript())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }

    private var displayedWord: DecodeWord? {
        let idx = pinnedWordIndex ?? orchestrator.wordIndex
        guard idx < orchestrator.words.count else { return nil }
        return orchestrator.words[idx]
    }

    private func tapPair(word: Word) -> some View {
        HStack(spacing: MoraTheme.Space.xl) {
            tapButton(strings.feedbackCorrect, color: MoraTheme.Feedback.correct) {
                feedback = .correct
                Task { @MainActor in
                    let priorIndex = orchestrator.wordIndex
                    pinnedWordIndex = priorIndex
                    await orchestrator.handle(.answerManual(correct: true))
                    try? await Task.sleep(nanoseconds: 450_000_000)
                    feedback = .none
                    pinnedWordIndex = nil
                }
            }
            tapButton(strings.feedbackTryAgain, color: MoraTheme.Feedback.wrong) {
                feedback = .wrong
                Task { @MainActor in
                    let priorIndex = orchestrator.wordIndex
                    pinnedWordIndex = priorIndex
                    await orchestrator.handle(.answerManual(correct: false))
                    try? await Task.sleep(nanoseconds: 650_000_000)
                    feedback = .none
                    pinnedWordIndex = nil
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
        guard let expected = displayedWord?.word else { return }
        lastHeard = ""
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
                    case .final(let recording):
                        // Pin the on-screen word to the trial we're judging
                        // BEFORE calling `orchestrator.handle`, so the
                        // orchestrator's index bump doesn't re-render the
                        // next word while corrective audio is still playing.
                        let priorIndex = orchestrator.wordIndex
                        pinnedWordIndex = priorIndex
                        lastHeard = recording.asr.transcript
                        micState = .assessing
                        try? await Task.sleep(nanoseconds: 120_000_000)
                        await orchestrator.handle(.answerHeard(recording))
                        let wasCorrect = orchestrator.trials.last?.correct ?? false
                        feedback = wasCorrect ? .correct : .wrong
                        if !wasCorrect, let speech {
                            // Awaiting the corrective utterance keeps the
                            // word pinned for the full playback. The
                            // underlying controller cancels this sequence if
                            // the session advances phase or the close button
                            // fires mid-utterance.
                            await speech.playAndAwait(
                                [.text("Listen: " + expected.surface, .slow)]
                            )
                        }
                        try? await Task.sleep(
                            nanoseconds: wasCorrect ? 450_000_000 : 650_000_000)
                        feedback = .none
                        micState = .idle
                        // Release the pin *after* the feedback window, so the
                        // next word only appears when we're ready for it.
                        pinnedWordIndex = nil
                        lastHeard = ""
                    }
                }
            } catch {
                micState = .idle
            }
        }
    }
}
