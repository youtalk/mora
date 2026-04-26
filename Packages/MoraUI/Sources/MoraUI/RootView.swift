import MoraCore
import SwiftData
import SwiftUI

public struct RootView: View {
    @State private var languageAgeOnboarded: Bool = UserDefaults.standard.bool(
        forKey: LanguageAgeState.onboardedKey
    )
    @State private var onboarded: Bool = UserDefaults.standard.bool(
        forKey: OnboardingState.onboardedKey
    )
    @State private var yokaiIntroSeen: Bool = UserDefaults.standard.bool(
        forKey: YokaiIntroState.onboardedKey
    )
    @Query(sort: \LearnerProfile.createdAt, order: .forward)
    private var profiles: [LearnerProfile]

    public init() {}

    public var body: some View {
        let (strings, l1) = resolved(profile: profiles.first)
        Group {
            if !languageAgeOnboarded {
                LanguageAgeFlow {
                    languageAgeOnboarded = true
                }
            } else if !onboarded {
                OnboardingFlow {
                    onboarded = true
                }
                .environment(\.moraStrings, strings)
                .environment(\.currentL1Profile, l1)
            } else if !yokaiIntroSeen {
                YokaiIntroFlow(mode: .firstTime) { yokaiIntroSeen = true }
                    .environment(\.moraStrings, strings)
                    .environment(\.currentL1Profile, l1)
            } else {
                NavigationStack {
                    HomeView()
                        .navigationDestination(for: String.self) { destination in
                            switch destination {
                            case "session": SessionContainerView()
                            case "bestiary":
                                BestiaryView()
                                    .environment(\.moraStrings, strings)
                                    .environment(\.currentL1Profile, l1)
                            case "curriculumComplete":
                                CurriculumCompleteView()
                                    .environment(\.moraStrings, strings)
                                    .environment(\.currentL1Profile, l1)
                            default: EmptyView()
                            }
                        }
                }
                .environment(\.moraStrings, strings)
                .environment(\.currentL1Profile, l1)
            }
        }
    }

    /// Resolve the active profile to (strings, L1Profile). Before onboarding
    /// completes, profile may be nil — fall back to JapaneseL1Profile at
    /// `.advanced` so screens still render with the same defaults as
    /// `MoraStringsKey.defaultValue`.
    private func resolved(profile: LearnerProfile?) -> (strings: MoraStrings, l1: any L1Profile) {
        guard let p = profile else {
            let fallback = JapaneseL1Profile()
            return (fallback.uiStrings(at: .advanced), fallback)
        }
        let l1 = L1ProfileResolver.profile(for: p.l1Identifier)
        return (l1.uiStrings(at: p.resolvedLevel), l1)
    }
}
