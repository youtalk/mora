import SwiftUI

public struct RootView: View {
    @State private var onboarded: Bool = UserDefaults.standard.bool(
        forKey: OnboardingState.onboardedKey
    )

    public init() {}

    public var body: some View {
        Group {
            if onboarded {
                NavigationStack {
                    HomeView()
                        .navigationDestination(for: String.self) { destination in
                            switch destination {
                            case "session": SessionContainerView()
                            default: EmptyView()
                            }
                        }
                }
            } else {
                OnboardingFlow {
                    onboarded = true
                }
            }
        }
    }
}
