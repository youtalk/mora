import MoraCore
import MoraEngines
import SwiftData
import SwiftUI

public struct HomeView: View {
    @Query private var profiles: [LearnerProfile]
    @Query private var streaks: [DailyStreak]

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
        #if os(iOS)
            .navigationBarHidden(true)
        #endif
    }

    private var header: some View {
        HStack {
            Text("mora")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Accent.orange)
            Spacer()
            StreakChip(count: streaks.first?.currentCount ?? 0)
        }
        .padding(MoraTheme.Space.md)
    }

    private var hero: some View {
        VStack(spacing: MoraTheme.Space.md) {
            Text("Today's quest")
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)

            Text(target.skill.graphemePhoneme?.grapheme.letters ?? "—")
                .font(MoraType.hero(180))
                .foregroundStyle(MoraTheme.Ink.primary)

            Text(ipaLine)
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.secondary)

            NavigationLink(value: "session") {
                // Match HeroCTA spec §6.4: 18pt Rounded Bold, orange capsule
                // with y=5 shadow. Inlined so NavigationLink owns the tap.
                Text("▶ Start")
                    .font(MoraType.cta())
                    .foregroundStyle(.white)
                    .padding(.horizontal, MoraTheme.Space.xl)
                    .padding(.vertical, MoraTheme.Space.md)
                    .frame(minHeight: 88)
                    .background(MoraTheme.Accent.orange, in: .capsule)
                    .shadow(color: MoraTheme.Accent.orangeShadow, radius: 0, x: 0, y: 5)
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

    private var curriculum: CurriculumEngine { CurriculumEngine.defaultV1Ladder() }

    private var target: Target {
        curriculum.currentTarget(forWeekIndex: weekIndex)
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
        guard let gp = target.skill.graphemePhoneme else { return "" }
        return "/\(gp.phoneme.ipa)/ · as in ship, shop, fish"
    }
}
