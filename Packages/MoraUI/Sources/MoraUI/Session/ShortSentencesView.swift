import MoraCore
import MoraEngines
import OSLog
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

private let micLog = Logger(subsystem: "tech.reenable.Mora", category: "Speech")

struct ShortSentencesView: View {
    @Environment(\.moraStrings) private var strings
    let orchestrator: SessionOrchestrator
    let uiMode: SessionUIMode
    @Binding var feedback: FeedbackState
    let speechEngine: SpeechEngine?
    let speech: SpeechController?
    /// Fires the first time the mic path resolves to a permanent
    /// "this device can't do mic" condition (today: macOS Dictation
    /// disabled). The container view flips `uiMode` to `.tap` so the
    /// learner can keep the session moving via the Correct / Try-again
    /// pair instead of being stuck on a silent mic button. Defaults to
    /// a no-op so existing previews / tests don't have to wire it up.
    var onSpeechUnavailable: () -> Void = {}

    @State private var micState: MicUIState = .idle
    @State private var shakeAmount: CGFloat = 0
    @State private var shakeResetTask: Task<Void, Never>?
    /// Pin the on-screen sentence to a specific orchestrator index during
    /// feedback / corrective audio. Without it, `orchestrator.handle(.answerHeard)`
    /// advances `sentenceIndex` immediately, the body re-renders the next
    /// sentence, and the "Listen:" audio then names the previous sentence.
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
                            speech?.play([.text(current.text, .slow)])
                        }

                    switch uiMode {
                    case .tap:
                        tapPair(sentence: current)
                    case .mic:
                        micStack
                    }

                    VStack(spacing: MoraTheme.Space.sm) {
                        Text(
                            strings.sessionSentenceCounter(
                                (pinnedSentenceIndex ?? orchestrator.sentenceIndex) + 1,
                                orchestrator.sentences.count
                            )
                        )
                        .font(MoraType.label())

                        Text(strings.sentencesLongPressHint)
                            .font(MoraType.subtitle())
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(MoraTheme.Ink.muted)
                    .minimumScaleFactor(0.5)

                    if !lastHeard.isEmpty,
                        let last = orchestrator.trials.last,
                        let phoneme = last.phoneme
                    {
                        let vm = PronunciationFeedbackViewModel(
                            assessment: phoneme, strings: strings)
                        if vm.hasContent {
                            PronunciationFeedbackOverlay(
                                viewModel: vm,
                                onAppearSpeak: { [weak speech] text in
                                    await speech?.playAndAwait([.text(text, .normal)])
                                }
                            )
                            .transition(.opacity.combined(with: .scale))
                            .padding(.top, MoraTheme.Space.md)
                        }
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
            transcriptSlot
        }
    }

    /// Fixed-height plate for the ASR read-out. The slot is always laid
    /// out at `Self.transcriptSlotHeight` whether or not a partial / final
    /// transcript is present, so the mic button and the counter/hint row
    /// below it keep a constant baseline — previously the transcript text
    /// appeared on the first partial and shoved every subsequent row
    /// down by one line height, which reads as a jump to the learner.
    private var transcriptSlot: some View {
        Text(activeTranscript)
            .font(MoraType.transcript())
            .foregroundStyle(MoraTheme.Ink.secondary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(
                maxWidth: .infinity,
                minHeight: Self.transcriptSlotHeight,
                alignment: .top
            )
            .animation(.easeInOut(duration: 0.15), value: activeTranscript)
            .accessibilityHidden(activeTranscript.isEmpty)
            .accessibilityLabel(Text("You said: \(activeTranscript)"))
    }

    /// Reserves two lines at 48pt transcript size — enough for the
    /// longest A-day sentence without growing past two lines on iPad.
    private static let transcriptSlotHeight: CGFloat = 120

    /// Current text to render in the transcript slot, or "" when idle.
    /// Hoisted out of the ViewBuilder so the slot can always exist in
    /// the layout tree (even when no transcript is available yet).
    private var activeTranscript: String {
        if case .listening(let partial) = micState, !partial.isEmpty {
            return partial
        }
        return lastHeard
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
        Self.logMic("startListening expected=\"\(expected.text)\"")
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
                        Self.logMic("event .started; state=listening")
                    case .partial(let text):
                        if case .listening = micState {
                            micState = .listening(partialText: text)
                        }
                    case .final(let recording):
                        Self.logMic(
                            """
                            event .final transcript=\"\(recording.asr.transcript)\" \
                            confidence=\(recording.asr.confidence) \
                            samples=\(recording.audio.samples.count)
                            """
                        )
                        let priorIndex = orchestrator.sentenceIndex
                        pinnedSentenceIndex = priorIndex
                        lastHeard = recording.asr.transcript
                        micState = .assessing
                        try? await Task.sleep(nanoseconds: 120_000_000)
                        await orchestrator.handle(.answerHeard(recording))
                        let wasCorrect = orchestrator.trials.last?.correct ?? false
                        Self.logMic("assess result correct=\(wasCorrect)")
                        feedback = wasCorrect ? .correct : .wrong
                        if !wasCorrect, let speech {
                            await speech.playAndAwait(
                                [.text("Listen: " + expected.text, .slow)]
                            )
                        }
                        try? await Task.sleep(
                            nanoseconds: wasCorrect ? 450_000_000 : 650_000_000)
                        feedback = .none
                        micState = .idle
                        pinnedSentenceIndex = nil
                        lastHeard = ""
                        Self.logMic("state=idle (post-assess)")
                    }
                }
            } catch {
                micLog.error(
                    "ASR listen failed: \(String(describing: error), privacy: .public)"
                )
                if let appleErr = error as? AppleSpeechEngineError,
                    appleErr == .dictationDisabled
                {
                    Self.logMic("speech unavailable (dictationDisabled); tap fallback")
                    onSpeechUnavailable()
                }
                micState = .idle
            }
        }
    }

    /// Pairs with `SessionOrchestrator.logLifecycle` and
    /// `SessionContainerView.logBootstrap`: same shape so the three
    /// streams interleave in Console.app and a DEBUG build can be read
    /// top-to-bottom as a timeline. Uses the file-private `micLog`
    /// (subsystem=tech.reenable.Mora, category=Speech) so a single
    /// `category == "Speech"` filter captures both this view's mic state
    /// transitions and `AppleSpeechEngine`'s ASR-internal events.
    private static func logMic(_ line: String) {
        #if DEBUG
        micLog.info("mic \(line, privacy: .public)")
        #else
        micLog.info("mic \(line, privacy: .private)")
        #endif
    }
}
