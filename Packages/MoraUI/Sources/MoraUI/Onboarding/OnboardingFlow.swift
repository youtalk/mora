import MoraCore
import Observation
import SwiftData
import SwiftUI

enum OnboardingStep: Equatable {
    case welcome, name, interests, permission, finished
}

@Observable
@MainActor
final class OnboardingState {
    var step: OnboardingStep = .welcome
    var name: String = ""
    var selectedInterests: Set<String> = []

    static let onboardedKey = "tech.reenable.Mora.onboarded"

    func advance() {
        switch step {
        case .welcome: step = .name
        case .name: step = .interests
        case .interests: step = .permission
        case .permission: step = .finished
        case .finished: break
        }
    }

    func skipName() {
        name = ""
        step = .interests
    }

    func finalize(
        in context: ModelContext,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) {
        let profile = LearnerProfile(
            displayName: name,
            l1Identifier: "ja",
            interests: Array(selectedInterests),
            preferredFontKey: "openDyslexic",
            createdAt: now
        )
        let streak = DailyStreak(currentCount: 0, longestCount: 0, lastCompletedOn: nil)
        context.insert(profile)
        context.insert(streak)
        try? context.save()
        defaults.set(true, forKey: Self.onboardedKey)
    }
}

public struct OnboardingFlow: View {
    @Environment(\.modelContext) private var context
    @State private var state = OnboardingState()
    private let profile = JapaneseL1Profile()
    private let onFinished: () -> Void

    public init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    public var body: some View {
        ZStack {
            MoraTheme.Background.page.ignoresSafeArea()
            stepView
        }
        .onChange(of: state.step) { _, new in
            if new == .finished {
                state.finalize(in: context)
                onFinished()
            }
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch state.step {
        case .welcome:
            WelcomeView(onContinue: { state.advance() })
        case .name:
            NameView(
                name: Binding(get: { state.name }, set: { state.name = $0 }),
                onContinue: { state.advance() },
                onSkip: { state.skipName() }
            )
        case .interests:
            InterestPickView(
                selectedKeys: Binding(
                    get: { state.selectedInterests },
                    set: { state.selectedInterests = $0 }
                ),
                categories: profile.interestCategories,
                onContinue: { state.advance() }
            )
        case .permission:
            PermissionRequestView(onContinue: { state.advance() })
        case .finished:
            ProgressView()
        }
    }
}
