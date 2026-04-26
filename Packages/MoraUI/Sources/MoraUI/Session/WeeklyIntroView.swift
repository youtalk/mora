import MoraCore
import MoraEngines
import SwiftData
import SwiftUI

/// Internal test seam: when set in the environment, `WeeklyIntroView`
/// publishes its replay action to this object so unit tests can fire it
/// without traversing the SwiftUI button hierarchy. Production code never
/// reads it.
@MainActor
final class WeeklyIntroViewTestHook {
    var tapReplay: (() -> Void)?
    var tapNext: (() -> Void)?
}

private struct WeeklyIntroTestHookKey: EnvironmentKey {
    static let defaultValue: WeeklyIntroViewTestHook? = nil
}

extension EnvironmentValues {
    var weeklyIntroTestHook: WeeklyIntroViewTestHook? {
        get { self[WeeklyIntroTestHookKey.self] }
        set { self[WeeklyIntroTestHookKey.self] = newValue }
    }
}

/// Pre-warmup intro shown on the first session of each yokai week.
/// Plays the active yokai's `.greet` clip and waits for the learner to
/// tap "Next" before the warmup phase view (and its TTS prompt) mounts.
///
/// Mounted only when `phase == .warmup` AND
/// `yokai.activeCutscene.isMondayIntro` is true; gated by
/// `SessionContainerView.content`. CTA wiring (`yokai.dismissCutscene()`)
/// is added in Task 4. Replay button is added in Task 3.
public struct WeeklyIntroView: View {
    @Environment(\.moraStrings) private var strings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.weeklyIntroTestHook) private var testHook: WeeklyIntroViewTestHook?
    @Bindable var yokai: YokaiOrchestrator
    let store: BundledYokaiStore?
    let player: any YokaiClipPlayer

    @State private var portraitScale: CGFloat = 0.8

    public init(
        yokai: YokaiOrchestrator,
        store: BundledYokaiStore?,
        player: any YokaiClipPlayer
    ) {
        self.yokai = yokai
        self.store = store
        self.player = player
    }

    public var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer().frame(height: MoraTheme.Space.xl)

            Text(strings.yokaiIntroTodayTitle)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)

            if let definition = yokai.currentYokai {
                portraitColumn(yokai: definition)
            } else {
                Color.clear.frame(height: 240)
            }

            Text(strings.yokaiIntroTodayBody)
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MoraTheme.Space.xl)

            if greetClipURL != nil {
                Button(action: replayGreet) {
                    Text(strings.warmupListenAgain)
                        .font(MoraType.cta())
                        .foregroundStyle(MoraTheme.Accent.teal)
                        .padding(.vertical, MoraTheme.Space.md)
                        .padding(.horizontal, MoraTheme.Space.xl)
                        .background(MoraTheme.Background.mint, in: .capsule)
                        .minimumScaleFactor(0.5)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            HeroCTA(title: strings.yokaiIntroNext, action: dismiss)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            playGreet()
            testHook?.tapReplay = { Task { @MainActor in self.replayGreet() } }
            testHook?.tapNext = { Task { @MainActor in self.dismiss() } }
            if reduceMotion {
                portraitScale = 1.0
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    portraitScale = 1.0
                }
            }
        }
        .onDisappear {
            player.stop()
        }
    }

    @ViewBuilder
    private func portraitColumn(yokai: YokaiDefinition) -> some View {
        VStack(spacing: MoraTheme.Space.sm) {
            YokaiPortraitCorner(yokai: yokai, sparkleTrigger: nil)
                .frame(width: 200, height: 200)
                .scaleEffect(portraitScale)
            Text(yokai.grapheme)
                .font(MoraType.heroWord(72))
                .foregroundStyle(MoraTheme.Ink.primary)
            Text(yokai.ipa)
                .font(MoraType.subtitle())
                .foregroundStyle(MoraTheme.Ink.secondary)
        }
    }

    private var greetClipURL: URL? {
        guard let id = yokai.currentYokai?.id else { return nil }
        return store?.voiceClipURL(for: id, clip: .greet)
    }

    private func playGreet() {
        guard let url = greetClipURL else { return }
        _ = player.play(url: url)
    }

    private func replayGreet() {
        guard let url = greetClipURL else { return }
        player.stop()
        _ = player.play(url: url)
    }

    private func dismiss() {
        player.stop()
        yokai.dismissCutscene()
    }
}

#if DEBUG
@MainActor
private func makePreviewOrchestrator(yokaiID: String) -> (YokaiOrchestrator, BundledYokaiStore) {
    let container = try! MoraModelContainer.inMemory()
    let ctx = ModelContext(container)
    let store = try! BundledYokaiStore()
    let orch = YokaiOrchestrator(store: store, modelContext: ctx)
    try! orch.startWeek(yokaiID: yokaiID, weekStart: Date())
    return (orch, store)
}

#Preview("Weekly intro — sh") {
    let (orch, store) = makePreviewOrchestrator(yokaiID: "sh")
    WeeklyIntroView(
        yokai: orch,
        store: store,
        player: AVFoundationYokaiClipPlayer()
    )
    .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#endif
