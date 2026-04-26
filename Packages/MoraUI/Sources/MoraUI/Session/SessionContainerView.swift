import MoraCore
import MoraEngines
import OSLog
import SwiftData
import SwiftUI

private let persistLog = Logger(subsystem: "tech.reenable.Mora", category: "Persistence")
private let speechLog = Logger(subsystem: "tech.reenable.Mora", category: "Speech")

public enum SessionUIMode: Equatable, Sendable {
    case tap
    case mic
}

public struct SessionContainerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.moraStrings) private var strings
    @Environment(\.shadowEvaluatorFactory) private var shadowEvaluatorFactory
    @Environment(\.speechEnginesWarmup) private var speechEnginesWarmup
    @Query(sort: \DailyStreak.lastCompletedOn, order: .reverse)
    private var streaks: [DailyStreak]
    @State private var orchestrator: SessionOrchestrator?
    @State private var bootError: String?
    @State private var feedback: FeedbackState = .none
    @State private var uiMode: SessionUIMode = .tap
    @State private var speechEngine: SpeechEngine?
    @State private var speech: SpeechController?
    @State private var showCloseConfirm = false
    @State private var clipRouter: YokaiClipRouter?
    /// True after the mic path reports `.dictationDisabled` for the first
    /// time on this run. Surfaces an alert pointing the user at macOS's
    /// Dictation toggle, then leaves `uiMode = .tap` so the session
    /// completes on tap input without a second pop-up on every trial.
    @State private var showDictationDisabledAlert = false

    public init() {}

    public var body: some View {
        ZStack {
            MoraTheme.Background.page.ignoresSafeArea()

            VStack(spacing: 0) {
                topChrome
                    .padding(.horizontal, MoraTheme.Space.md)
                    .padding(.top, MoraTheme.Space.md)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, MoraTheme.Space.xxl)
                    .animation(.easeInOut(duration: 0.25), value: orchestrator?.phase)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            FeedbackOverlay(state: feedback)

            if let yokai = orchestrator?.yokai {
                YokaiLayerView(orchestrator: yokai, speech: speech)
                    .ignoresSafeArea()
            }
        }
        .alert("Microphone unavailable", isPresented: $showDictationDisabledAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                """
                To use the mic on Mac, enable Dictation in System Settings → \
                Apple Intelligence & Siri → Dictation. The session will \
                continue with tap input for now.
                """
            )
        }
        .alert(strings.sessionCloseTitle, isPresented: $showCloseConfirm) {
            Button(strings.sessionCloseKeepGoing, role: .cancel) {}
            Button(strings.sessionCloseEnd, role: .destructive) {
                // Record a partial summary so progress is not silently dropped.
                if let orchestrator {
                    let partial = orchestrator.sessionSummary(endedAt: Date())
                    persist(summary: partial)
                }
                // Cancel in-flight speech and any yokai clip, then dismiss.
                // `clipRouter?.stop()` is synchronous so it lands first;
                // awaiting `speech.stop()` before `dismiss()` is what stops
                // the tail of the current utterance from riding out onto
                // whatever screen the learner lands on next — a detached
                // stop racing against dismiss leaves the audio audible.
                clipRouter?.stop()
                if let speech {
                    Task { @MainActor in
                        await speech.stop()
                        dismiss()
                    }
                } else {
                    dismiss()
                }
            }
        } message: {
            Text(strings.sessionCloseMessage)
        }
        // Stale prior-phase audio is silenced by the new phase view's
        // own `speech.play(...)` call — `play()` cancels any in-flight
        // sequence before starting the new one (see `SpeechController`).
        // A parent-level `.onChange(phase) { speech.stop() }` would race
        // with the new view's `.task` on @MainActor and, when scheduled
        // *after* the new `play()` set its inflight task, would cancel
        // the new playback. The only phase view that does NOT auto-play
        // on entry is `ShortSentencesView`; it owns its own
        // `await speech?.stop()` so a prior phase's TTS does not leak
        // into the mic-listening window. The same race applies to
        // `clipRouter`: each phase that fires a clip drives it from its
        // own `.task`, and `clipRouter.play(...)` calls the silencer
        // before starting playback, so a parent-level `clipRouter.stop()`
        // on phase change is not needed and would cancel the new clip.
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
    }

    private var topChrome: some View {
        HStack {
            Button(action: { showCloseConfirm = true }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MoraTheme.Ink.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.6), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(strings.a11yCloseSession)
            .accessibilityHint("Confirms before leaving so you don't lose progress.")

            Spacer()

            if let orchestrator {
                PhasePips(phase: orchestrator.phase)
            } else {
                PhasePips(currentIndex: -1)
            }

            Spacer()

            StreakChip(count: streaks.first?.currentCount ?? 0)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let orchestrator {
            switch orchestrator.phase {
            case .notStarted:
                ProgressView("Preparing…")
                    .task { await orchestrator.start() }
            case .warmup:
                WarmupView(orchestrator: orchestrator, speech: speech, clipRouter: clipRouter)
            case .newRule:
                NewRuleView(orchestrator: orchestrator, speech: speech)
            case .decoding:
                VStack(spacing: MoraTheme.Space.md) {
                    if let engine = orchestrator.currentTileBoardEngine {
                        DecodeBoardView(
                            engine: engine,
                            chainPipStates: orchestrator.chainPipStates.map(ChainPipState.init),
                            incomingRole: orchestrator.currentChainRole,
                            speech: speech,
                            onTrialComplete: { result in
                                orchestrator.consumeTileBoardTrial(result)
                            }
                        )
                        .id(orchestrator.completedTrialCount)
                    } else {
                        Color.clear
                    }
                    #if DEBUG
                    // Dev-only shortcut to reach ShortSentences (the only
                    // phase that exercises Engine A/B) in a few taps during
                    // on-device iteration. Stripped from Release builds.
                    Button("DEBUG: Skip to Short Sentences") {
                        orchestrator.debugSkipDecoding()
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .padding(.bottom, MoraTheme.Space.sm)
                    #endif
                }
                .task(id: orchestrator.completedTrialCount) {
                    let idx = orchestrator.completedTrialCount
                    let clip: YokaiClipKey?
                    switch idx {
                    case 0: clip = .example1
                    case 3: clip = .example2
                    case 7: clip = .example3
                    default: clip = nil
                    }
                    guard let clip else { return }
                    // Wait for the in-trial Apple TTS speakTarget() to finish before
                    // triggering the yokai exemplar; the single-word utterance reliably
                    // finishes inside this 1.5s window. If SwiftUI cancels the task
                    // (phase change or trial-id update) the throwing sleep exits
                    // here so the clip never fires on a stale id.
                    do {
                        try await Task.sleep(for: .milliseconds(1500))
                    } catch {
                        return
                    }
                    await clipRouter?.play(clip)
                }
            case .shortSentences:
                ShortSentencesView(
                    orchestrator: orchestrator, uiMode: uiMode,
                    feedback: $feedback,
                    speechEngine: uiMode == .mic ? speechEngine : nil,
                    speech: speech,
                    clipRouter: clipRouter,
                    onSpeechUnavailable: handleSpeechUnavailable
                )
            case .completion:
                CompletionView(
                    orchestrator: orchestrator, speech: speech,
                    persistSummary: { summary in persist(summary: summary) }
                )
            }
        } else if let bootError {
            Text("Could not start session: \(bootError)")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
        } else {
            ProgressView("Loading session…")
                .task { await bootstrap() }
        }
    }

    /// Resolves the per-session sentence triple for `bootstrap()`. Tries the
    /// bundled `SentenceLibrary` first; if it returns fewer than `count`
    /// sentences (cell unauthored, or pool too sparse), falls back to the
    /// per-week `<skill>_week.json` via `ScriptedContentProvider.bundled`.
    /// A bundle/decode failure on the fallback path throws so `bootstrap`'s
    /// surrounding `do/catch` can surface it as `bootError`, matching the
    /// pre-Track-B failure visibility.
    ///
    /// Package-internal because `SessionContainerBootstrapLibraryTests`
    /// drives this directly without spinning up SwiftUI. Kept `static` so it
    /// has no instance dependencies and is trivially testable; bootstrap
    /// resolves all inputs and passes them in. Not `@MainActor` so the sync
    /// JSON load on the fallback path can run off the main actor.
    static func resolveDecodeSentences(
        library: SentenceLibrary,
        skillCode: SkillCode,
        targetGrapheme: Grapheme,
        taughtGraphemes: Set<Grapheme>,
        ageYears: Int,
        interests: [String],
        count: Int
    ) async throws -> [DecodeSentence] {
        let primary = await library.sentences(
            target: skillCode,
            interests: interests,
            ageYears: ageYears,
            excluding: [],
            count: count
        )
        if primary.count >= count { return primary }

        // Fallback: per-week hand-authored JSON. Bundle/decode failures
        // propagate so bootstrap's `do/catch` sets `bootError`.
        let provider = try ScriptedContentProvider.bundled(for: skillCode)
        let request = ContentRequest(
            target: targetGrapheme,
            taughtGraphemes: taughtGraphemes,
            interests: [],
            count: count
        )
        return try provider.decodeSentences(request)
    }

    @MainActor
    private func bootstrap() async {
        Self.logBootstrap("bootstrap start")
        // Yield once so the NavigationStack push animation can paint the
        // "Loading session…" frame before bootstrap's synchronous
        // main-actor work begins. Without this, `.task` runs at frame 0
        // of the push transition and the heavy steps below (engine init,
        // first-launch SwiftData saves, JSON decodes) hold the main
        // thread for the entire animation, dropping frames and producing
        // a visible stutter on the way into the session.
        await Task.yield()
        #if os(iOS)
        // Decide mic vs tap before building the engine — if the user
        // denied either permission, skip engine construction entirely.
        let coord = PermissionCoordinator()
        let permission = coord.current()
        Self.logBootstrap("permission state=\(permission)")
        switch permission {
        case .allGranted:
            // Prefer the app-target's pre-warmed engine if it resolved
            // already — `SpeechEnginesWarmup` runs the
            // `SFSpeechRecognizer(locale:)` lazy-load (~100–500 ms on
            // cold launch) on a detached `.utility` task at app launch,
            // so by the time the learner finishes onboarding (first
            // launch) or even glances at the home hero card (every
            // launch after that) it's almost always ready and we can
            // skip the inline construction entirely.
            if let warmup = speechEnginesWarmup, warmup.isResolved {
                if let engine = warmup.speechEngine {
                    speechEngine = engine
                    uiMode = .mic
                    Self.logBootstrap("AppleSpeechEngine init ok (pre-warmed); uiMode=mic")
                } else {
                    // Warmup ran and speech init failed (older device,
                    // simulator without on-device Speech support,
                    // missing locale model). Fall back to tap mode
                    // without re-trying — the failure is recorded in
                    // `warmup.speechFailureReason` for diagnostics.
                    uiMode = .tap
                    let reason = warmup.speechFailureReason ?? "unknown"
                    Self.logBootstrap("uiMode=tap (warmup speech failed: \(reason))")
                }
            } else {
                // Cold path: warmup wasn't wired (preview / test host)
                // or hasn't resolved yet (user tapped within ~500 ms
                // of app launch on a host that lacks the onboarding
                // head-start). Construct inline with the same
                // cancellation-aware detached pattern the warmup
                // itself uses, so the fallback still doesn't block
                // the navigation push animation.
                let engineTask = Task.detached(priority: .userInitiated) {
                    try AppleSpeechEngine()
                }
                do {
                    let engine = try await withTaskCancellationHandler {
                        try await engineTask.value
                    } onCancel: {
                        engineTask.cancel()
                    }
                    try Task.checkCancellation()
                    speechEngine = engine
                    uiMode = .mic
                    Self.logBootstrap("AppleSpeechEngine init ok (inline); uiMode=mic")
                } catch is CancellationError {
                    Self.logBootstrap("bootstrap cancelled during AppleSpeechEngine init")
                    return
                } catch {
                    speechLog.error(
                        "AppleSpeechEngine init failed, falling back to tap: \(String(describing: error))"
                    )
                    uiMode = .tap
                    Self.logBootstrap("uiMode=tap (engine init failed)")
                }
            }
        case .partial, .notDetermined:
            uiMode = .tap
            Self.logBootstrap("uiMode=tap (permission \(permission))")
        }
        // Same pre-warm-or-fallback split as the speech path. The
        // warmup target always sets `ttsEngine` once `.resolved`
        // (AVSpeechSynthesizer construction never throws), so the
        // pre-warmed branch is the common case and the inline branch
        // only runs in previews / tests / a session that beat the
        // warmup task to ready.
        let tts: any TTSEngine
        if let warmup = speechEnginesWarmup, warmup.isResolved,
            let warmedTTS = warmup.ttsEngine
        {
            tts = warmedTTS
            Self.logBootstrap("AppleTTSEngine init ok (pre-warmed)")
        } else {
            let ttsTask = Task.detached(priority: .userInitiated) {
                AppleTTSEngine(l1Profile: JapaneseL1Profile())
            }
            let inlineTTS = await withTaskCancellationHandler {
                await ttsTask.value
            } onCancel: {
                ttsTask.cancel()
            }
            if Task.isCancelled {
                Self.logBootstrap("bootstrap cancelled during AppleTTSEngine init")
                return
            }
            tts = inlineTTS
            Self.logBootstrap("AppleTTSEngine init ok (inline)")
        }
        speech = SpeechController(tts: tts)
        // Prime AVSpeechSynthesizer so the warmup phoneme isn't the
        // utterance that gets eaten by the cold-launch first-utterance
        // quirk: on a fresh audio session the very first short speak()
        // sometimes never fires `didFinish`, leaving the queue stalled
        // and the learner's first prompt silent. A space-only primer
        // routed through `SpeechController` takes that hit on a no-op
        // so the real prompt plays cleanly — and because it goes through
        // the controller's `inflight`, the warmup view's first
        // `speech.play(...)` cancels it via the same chokepoint as any
        // other in-flight sequence.
        speech?.play([.text(" ", .normal)])
        #else
        uiMode = .tap
        #endif

        do {
            let ladder = CurriculumEngine.sharedV1
            guard
                let resolution = try WeekRotation.resolve(
                    context: context,
                    ladder: ladder
                )
            else {
                // All five yokai befriended. HomeView's CTA has already
                // routed to the curriculum-complete terminal screen; if a
                // session somehow still starts (e.g. a stale deep link)
                // just bounce straight back to the caller.
                dismiss()
                return
            }
            let skill = resolution.skill
            let target = Target(weekStart: resolution.encounter.weekStart, skill: skill)
            let weekIdx = ladder.indexOf(code: skill.code) ?? 0
            let taught = ladder.taughtGraphemes(beforeWeekIndex: weekIdx)
            guard let targetGrapheme = target.grapheme else {
                bootError =
                    "Target skill \(skill.code.rawValue) has no grapheme/phoneme mapping"
                return
            }
            // Resolve the learner's interests + age band from the singleton profile.
            // Falls back to (8, []) if the row is missing (defensive — onboarding
            // always creates one before a session starts). Fetch errors throw
            // into the surrounding `do/catch` so store corruption surfaces as
            // `bootError` rather than silently degrading to defaults.
            let profileFetch = FetchDescriptor<LearnerProfile>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            let profile = try context.fetch(profileFetch).first
            let interests = profile?.interests ?? []
            let ageYears = profile?.ageYears ?? 8

            let library = try SentenceLibrary()
            let sentences = try await Self.resolveDecodeSentences(
                library: library,
                skillCode: skill.code,
                targetGrapheme: targetGrapheme,
                taughtGraphemes: taught,
                ageYears: ageYears,
                interests: interests,
                count: 3
            )

            let progression = ClosureYokaiProgressionSource { currentID in
                ladder.skills
                    .first(where: { $0.yokaiID == currentID })
                    .flatMap { ladder.nextSkill(after: $0.code) }
                    .flatMap { $0.yokaiID }
            }
            let yokaiOrchestrator: YokaiOrchestrator?
            do {
                let store = try BundledYokaiStore()
                let orch = YokaiOrchestrator(
                    store: store,
                    modelContext: context,
                    progressionSource: progression
                )
                // An encounter inserted by the Friday handoff (after a
                // prior yokai befriended) has sessionCompletionCount == 0
                // and friendshipPercent == 0 — the learner hasn't entered
                // its Monday yet. Treat it as a fresh week so the Monday
                // intro cutscene and the 10% seed from startWeek both
                // fire; otherwise resume() would silently skip them.
                let enc = resolution.encounter
                let encYokaiID = enc.yokaiID
                let isUnstartedHandoff =
                    enc.sessionCompletionCount == 0 && enc.friendshipPercent == 0
                if resolution.isNewEncounter || isUnstartedHandoff {
                    try orch.startWeek(
                        yokaiID: encYokaiID,
                        weekStart: enc.weekStart
                    )
                    // startWeek inserts its own encounter; the existing one
                    // (either WeekRotation's fresh insert or the handoff's
                    // zero-state row) is superseded. Delete it so the store
                    // has exactly one active encounter for this yokai and
                    // the orchestrator-owned one drives cutscene state.
                    context.delete(enc)
                    try context.save()
                } else {
                    orch.resume(encounter: enc)
                    if enc.sessionCompletionCount == 4 {
                        // trialsPlanned matches the total trial budget for a
                        // session: tile-board phase emits one trial per chain
                        // link (up to 12), sentences phase emits up to
                        // `sentences.count` trials (3 here). Use an upper bound
                        // so floor math always reaches 100%.
                        orch.beginFridaySession(trialsPlanned: 15)
                    }
                }
                yokaiOrchestrator = orch
                let speechRef = speech
                self.clipRouter = YokaiClipRouter(
                    yokaiID: encYokaiID,
                    store: store,
                    player: AVFoundationYokaiClipPlayer(),
                    silencer: { [weak speechRef] in
                        await speechRef?.stop()
                    }
                )
            } catch {
                speechLog.error(
                    "YokaiOrchestrator init failed: \(String(describing: error))"
                )
                yokaiOrchestrator = nil
            }

            self.orchestrator = SessionOrchestrator(
                target: target,
                taughtGraphemes: taught,
                warmupOptions: skill.warmupCandidates,
                chainProvider: LibraryFirstWordChainProvider(),
                sentences: sentences,
                assessment: AssessmentEngine(
                    l1Profile: JapaneseL1Profile(),
                    evaluator: shadowEvaluatorFactory.make(context.container)
                ),
                yokai: yokaiOrchestrator
            )
            Self.logBootstrap(
                "orchestrator created skill=\(skill.code.rawValue) sentences=\(sentences.count)"
            )
        } catch {
            bootError = String(describing: error)
            Self.logBootstrap("bootstrap failed: \(String(describing: error))")
        }
    }

    /// Pairs with `SessionOrchestrator.logLifecycle`: same shape so the
    /// two streams interleave cleanly in Console.app and a DEBUG build
    /// reads top-to-bottom as a timeline. Routes through `speechLog`
    /// so a `category == "Speech"` filter captures every session-startup
    /// signal (permission state, mic vs tap, engine init outcome,
    /// orchestrator construction) alongside the per-trial mic events.
    private static func logBootstrap(_ line: String) {
        #if DEBUG
        speechLog.info("\(line, privacy: .public)")
        #else
        speechLog.info("\(line, privacy: .private)")
        #endif
    }

    /// Fires when `ShortSentencesView`'s mic path observes a permanent
    /// "this device can't do mic" condition (today only macOS Dictation
    /// disabled). Flip `uiMode` to `.tap` so the trial loop can finish
    /// via the Correct / Try-again pair, drop the speech engine so the
    /// next session start doesn't reuse it, and surface a one-shot
    /// alert pointing the user at the macOS Dictation toggle. Idempotent
    /// — repeated calls on later trials are no-ops because `uiMode` is
    /// already `.tap`.
    @MainActor
    private func handleSpeechUnavailable() {
        guard uiMode == .mic else { return }
        Self.logBootstrap("speech unavailable; uiMode mic→tap (dictation disabled)")
        uiMode = .tap
        speechEngine = nil
        showDictationDisabledAlert = true
    }

    @MainActor
    private func persist(summary: SessionSummary) {
        let entity = SessionSummaryEntity(
            date: Date(),
            sessionType: summary.sessionType.rawValue,
            targetSkillCode: summary.targetSkillCode.rawValue,
            durationSec: summary.durationSec,
            trialsTotal: summary.trialsTotal,
            trialsCorrect: summary.trialsCorrect,
            escalated: summary.escalated
        )
        context.insert(entity)
        do {
            try context.save()
        } catch {
            // Best-effort: a save failure here means the session log is lost
            // for this run, but the in-memory orchestrator state still
            // reflects what the learner just did. Surface to Console so the
            // failure is debuggable; do not crash the celebration screen.
            persistLog.error("SessionSummary save failed: \(error)")
        }
    }
}
