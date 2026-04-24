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
                            case "bestiary":
                                BestiaryView()
                                    .environment(\.moraStrings, resolvedStrings)
                            case "curriculumComplete":
                                CurriculumCompleteView()
                                    .environment(\.moraStrings, resolvedStrings)
                            default: EmptyView()
                            }
                        }
                }
                .environment(\.moraStrings, resolvedStrings)
            }
        }
    }

    /// Build the string catalog from the active profile. Before onboarding
    /// completes, age may be nil — default to 8 (matches
    /// `MoraStringsKey.defaultValue`) so screens still render.
    ///
    /// Alpha only ships `JapaneseL1Profile`, so every profile renders JP.
    /// When a second `L1Profile` lands, switch on `profile?.l1Identifier`
    /// here and return the matching profile's `uiStrings`.
    private var resolvedStrings: MoraStrings {
        let years = profiles.first?.ageYears ?? 8
        return JapaneseL1Profile().uiStrings(forAgeYears: years)
    }
}
