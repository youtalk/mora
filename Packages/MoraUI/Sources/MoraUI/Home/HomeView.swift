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

    // `needsEnhancedVoice` walks the installed-voice list; keep the result in
    // @State so the scan runs at most once per appearance / scene activation
    // rather than on every body invalidation (which fires on every @Query
    // update). Recomputed on scenePhase → .active so returning from Settings
    // after downloading a premium voice flips the prompt off immediately.
    @State private var needsBetterVoice: Bool = AppleTTSEngine.needsEnhancedVoice
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        ZStack {
            MoraTheme.Background.page.ignoresSafeArea()

            VStack(spacing: MoraTheme.Space.lg) {
                header
                Spacer()
                hero
                Spacer()
            }
        }
        .onAppear { needsBetterVoice = AppleTTSEngine.needsEnhancedVoice }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                needsBetterVoice = AppleTTSEngine.needsEnhancedVoice
            }
        }
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
    }

    private var header: some View {
        HStack {
            Text("Mora")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Accent.orange)
            Spacer()
            if needsBetterVoice {
                Button(action: openVoiceSettings) {
                    Text("Better voice ›")
                        .font(MoraType.pill())
                        .foregroundStyle(MoraTheme.Ink.secondary)
                        .padding(.horizontal, MoraTheme.Space.md)
                        .padding(.vertical, MoraTheme.Space.sm)
                        .background(MoraTheme.Background.cream, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Open iOS Settings to download an enhanced voice.")
            }
            StreakChip(count: streaks.first?.currentCount ?? 0)
        }
        .padding(MoraTheme.Space.md)
    }

    private var hero: some View {
        VStack(spacing: MoraTheme.Space.md) {
            Text("Today's quest")
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)

            Text(target.letters ?? "—")
                .font(MoraType.hero(180))
                .foregroundStyle(MoraTheme.Ink.primary)

            Text(ipaLine)
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.secondary)

            NavigationLink(value: "session") {
                Text("▶ Start")
                    .font(MoraType.cta())
                    .foregroundStyle(.white)
                    .padding(.horizontal, MoraTheme.Space.xl)
                    .padding(.vertical, MoraTheme.Space.md)
                    .frame(minHeight: 88)
                    .background(MoraTheme.Accent.orange, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.top, MoraTheme.Space.md)

            HStack(spacing: MoraTheme.Space.sm) {
                pill("16 min")
                pill("5 words")
                pill("2 sentences")
            }
        }
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
        CurriculumEngine.sharedV1.currentTarget(forWeekIndex: weekIndex)
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

    private func openVoiceSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
