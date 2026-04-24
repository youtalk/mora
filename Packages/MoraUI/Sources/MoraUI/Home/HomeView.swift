import MoraCore
import MoraEngines
import SwiftData
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public struct HomeView: View {
    // Sort by createdAt so if duplicate rows ever appear (migration bug, test
    // seed leaking into prod store), the oldest profile wins deterministically.
    @Query(sort: \LearnerProfile.createdAt, order: .forward)
    private var profiles: [LearnerProfile]

    // DailyStreak is a singleton; sort by lastCompletedOn so the most recent
    // one surfaces even if a stale row exists.
    @Query(sort: \DailyStreak.lastCompletedOn, order: .reverse)
    private var streaks: [DailyStreak]

    // Open encounters (active or carryover) — the hero reads the latest one
    // so the home screen shows the yokai the learner is currently working
    // with rather than a fixed week-0 fallback.
    //
    // Raw strings are used directly because `#Predicate` cannot form a key
    // path into an enum case (`\.active`), so `YokaiEncounterState.active`
    // .rawValue doesn't compile inside the macro. `YokaiEncounterStateRawValuesTests`
    // pins these strings to the enum cases so a rename breaks CI, not prod.
    @Query(
        filter: #Predicate<YokaiEncounterEntity> {
            $0.stateRaw == "active" || $0.stateRaw == "carryover"
        },
        sort: \YokaiEncounterEntity.weekStart,
        order: .reverse
    )
    private var openEncounters: [YokaiEncounterEntity]

    // `needsEnhancedVoice` walks the installed-voice list; keep the result in
    // @State so the scan runs at most once per appearance / scene activation
    // rather than on every body invalidation (which fires on every @Query
    // update). Recomputed on scenePhase → .active so returning from Settings
    // after downloading a premium voice flips the gate off immediately.
    @State private var needsBetterVoice: Bool = AppleTTSEngine.needsEnhancedVoice
    @State private var installedVoices: [String] = AppleTTSEngine.installedEnglishVoiceSummaries()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.moraStrings) private var strings
    @Environment(\.mlxWarmupState) private var warmup

    public init() {}

    public var body: some View {
        ZStack {
            MoraTheme.Background.page.ignoresSafeArea()

            VStack(spacing: MoraTheme.Space.lg) {
                header
                Spacer()
                if needsBetterVoice {
                    voiceGate
                } else {
                    hero
                }
                Spacer()
            }
        }
        .onAppear { refreshVoiceState() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshVoiceState() }
        }
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
    }

    private var header: some View {
        HStack {
            wordmark
            Spacer()
            StreakChip(count: streaks.first?.currentCount ?? 0)
        }
        .padding(MoraTheme.Space.md)
    }

    private var wordmark: some View {
        Text("Mora")
            .font(MoraType.heading())
            .foregroundStyle(MoraTheme.Accent.orange)
    }

    private var hero: some View {
        VStack(spacing: MoraTheme.Space.md) {
            Text(strings.homeTodayQuest)
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)

            Text(target.letters ?? "—")
                .font(MoraType.heroWord())
                .foregroundStyle(MoraTheme.Ink.primary)

            Text(ipaLine)
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .multilineTextAlignment(.center)

            NavigationLink(value: "session") {
                ZStack {
                    Text(strings.homeStart)
                        .font(MoraType.cta())
                        .foregroundStyle(.white)
                        .opacity(isStartEnabled ? 1 : 0)
                    if !isStartEnabled {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, MoraTheme.Space.xl)
                .padding(.vertical, MoraTheme.Space.md)
                .frame(minHeight: 88)
                .background(MoraTheme.Accent.orange, in: .capsule)
                .opacity(isStartEnabled ? 1 : 0.7)
            }
            .buttonStyle(.plain)
            .padding(.top, MoraTheme.Space.md)
            .disabled(!isStartEnabled)
            .accessibilityLabel(Text(strings.homeStart))
            .accessibilityValue(isStartEnabled ? Text("") : Text(strings.a11yHomeStartLoading))

            HStack(spacing: MoraTheme.Space.sm) {
                pill(strings.homeDurationPill(16))
                pill(strings.homeWordsPill(5))
                pill(strings.homeSentencesPill(2))
            }

            NavigationLink(value: "bestiary") {
                Label("Sound-Friend Register", systemImage: "book.closed.fill")
            }
            .buttonStyle(.bordered)
        }
    }

    /// Blocking setup card shown when no `.enhanced` / `.premium` English
    /// voice is installed. The system default compact voice at any rate below
    /// 0.5 turns "ship" into unintelligible noise on device, so we refuse to
    /// start a session until the parent installs a usable voice. The Recheck
    /// button re-runs the voice scan immediately after the user returns from
    /// Settings — scenePhase → .active also triggers a re-scan, but an
    /// explicit button makes the flow obvious.
    private var voiceGate: some View {
        VStack(spacing: MoraTheme.Space.md) {
            Text(strings.voiceGateTitle)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)

            Text(strings.voiceGateBody)
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // List what AVSpeechSynthesizer actually sees on this device —
            // lets the parent tell at a glance whether their Settings
            // download produced an Enhanced/Premium entry or left them
            // stuck on Default (compact).
            installedVoicesSection

            Button(action: openVoiceSettings) {
                Text(strings.voiceGateOpenSettings)
                    .font(MoraType.cta())
                    .foregroundStyle(.white)
                    .padding(.horizontal, MoraTheme.Space.xl)
                    .padding(.vertical, MoraTheme.Space.md)
                    .frame(minHeight: 72)
                    .background(MoraTheme.Accent.orange, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.top, MoraTheme.Space.sm)

            Button(action: refreshVoiceState) {
                Text(strings.voiceGateRecheck)
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Accent.teal)
                    .padding(.vertical, MoraTheme.Space.sm)
                    .padding(.horizontal, MoraTheme.Space.md)
            }
            .buttonStyle(.plain)
        }
        .padding(MoraTheme.Space.lg)
        .background(MoraTheme.Background.cream, in: .rect(cornerRadius: MoraTheme.Radius.card))
        .padding(.horizontal, MoraTheme.Space.xl)
    }

    private var installedVoicesSection: some View {
        VStack(alignment: .leading, spacing: MoraTheme.Space.xs) {
            Text(strings.voiceGateInstalledVoicesTitle)
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)
            if installedVoices.isEmpty {
                Text(strings.voiceGateNoVoicesPlaceholder)
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Ink.secondary)
            } else {
                ForEach(installedVoices, id: \.self) { row in
                    Text("• \(row)")
                        .font(MoraType.label())
                        .foregroundStyle(MoraTheme.Ink.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MoraTheme.Space.md)
        .background(.white, in: .rect(cornerRadius: MoraTheme.Radius.tile))
    }

    private func refreshVoiceState() {
        needsBetterVoice = AppleTTSEngine.needsEnhancedVoice
        installedVoices = AppleTTSEngine.installedEnglishVoiceSummaries()
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(MoraType.pill())
            .foregroundStyle(MoraTheme.Ink.secondary)
            .padding(.horizontal, MoraTheme.Space.md)
            .padding(.vertical, MoraTheme.Space.sm)
            .background(MoraTheme.Background.cream, in: .capsule)
    }

    private var target: Target {
        let ladder = CurriculumEngine.sharedV1
        if let enc = openEncounters.first,
            let skill = ladder.skills.first(where: { $0.yokaiID == enc.yokaiID })
        {
            return Target(weekStart: enc.weekStart, skill: skill)
        }
        return ladder.currentTarget(forWeekIndex: weekIndex)
    }

    /// Weeks elapsed since the learner's profile was created, clamped into the
    /// curriculum. When no profile exists (pre-onboarding state in PR 3 before
    /// PR 4 lands), default to week 0 so the hero renders something.
    private var weekIndex: Int {
        guard let profile = profiles.first else { return 0 }
        let seconds = Date().timeIntervalSince(profile.createdAt)
        return Int(seconds / (60 * 60 * 24 * 7))
    }

    private var ipaLine: String {
        guard let ipa = target.ipa else { return "" }
        return "/\(ipa)/ · as in ship, shop, fish"
    }

    /// `nil` environment means no app-level warmup is wired (previews,
    /// tests, legacy callsites) — treat as "don't gate". Otherwise unblock
    /// as soon as the load resolves, whether it succeeded or failed;
    /// Engine A still runs when Engine B isn't available.
    private var isStartEnabled: Bool {
        guard let warmup else { return true }
        return warmup.isResolved
    }

    private func openVoiceSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
