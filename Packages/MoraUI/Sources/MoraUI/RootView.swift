import SwiftUI

public struct RootView: View {
    @State private var languageAgeOnboarded: Bool = UserDefaults.standard.bool(
        forKey: LanguageAgeState.onboardedKey
    )
    @State private var onboarded: Bool = UserDefaults.standard.bool(
        forKey: OnboardingState.onboardedKey
    )

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
            }
        }
    }
}
