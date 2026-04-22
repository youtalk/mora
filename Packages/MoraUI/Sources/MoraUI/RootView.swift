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
    @Query(sort: \LearnerProfile.createdAt, order: .forward)
    private var profiles: [LearnerProfile]

    public init() {}

    public var body: some View {
        Group {
            if !languageAgeOnboarded {
                LanguageAgeFlow {
                    languageAgeOnboarded = true
                }
            } else if !onboarded {
                OnboardingFlow {
                    onboarded = true
                }
                .environment(\.moraStrings, resolvedStrings)
            } else {
                NavigationStack {
                    HomeView()
                        .navigationDestination(for: String.self) { destination in
                            switch destination {
                            case "session": SessionContainerView()
                            default: EmptyView()
                            }
                        }
                }
                .environment(\.moraStrings, resolvedStrings)
            }
        }
    }

    /// Build the string catalog from the active profile's l1 + age. Before
    /// onboarding completes, age may be nil — in which case we default to
    /// 8 (same as MoraStringsKey.defaultValue) so screens still render.
    private var resolvedStrings: MoraStrings {
        let profile = profiles.first
        let years = profile?.ageYears ?? 8
        switch profile?.l1Identifier {
        case "ja", nil: return JapaneseL1Profile().uiStrings(forAgeYears: years)
        default: return JapaneseL1Profile().uiStrings(forAgeYears: years)
        }
    }
}
