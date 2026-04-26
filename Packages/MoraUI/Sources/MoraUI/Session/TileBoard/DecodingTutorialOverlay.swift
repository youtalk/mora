import Foundation
import MoraCore
import Observation
import SwiftUI

@Observable
@MainActor
final class DecodingTutorialState {
    enum Step: Equatable, CaseIterable {
        case slot, audio, finished
    }

    var step: Step = .slot

    static let seenKey = "tech.reenable.Mora.decodingTutorialSeen"

    func advance() {
        switch step {
        case .slot: step = .audio
        case .audio: step = .finished
        case .finished: break
        }
    }

    func dismiss(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: Self.seenKey)
    }
}

public struct DecodingTutorialOverlay: View {
    @State private var state = DecodingTutorialState()
    private let mode: OnboardingPlayMode
    private let onFinished: () -> Void

    public init(mode: OnboardingPlayMode, onFinished: @escaping () -> Void) {
        self.mode = mode
        self.onFinished = onFinished
    }

    public var body: some View {
        ZStack {
            MoraTheme.Background.page.ignoresSafeArea()
            stepView
                .transition(
                    .move(edge: .leading).combined(with: .opacity)
                )
        }
        .animation(.easeInOut(duration: 0.3), value: state.step)
        .onChange(of: state.step) { _, newStep in
            if newStep == .finished {
                if mode == .firstTime {
                    state.dismiss()
                }
                onFinished()
            }
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch state.step {
        case .slot:
            SlotMeaningPanel { state.advance() }
        case .audio:
            AudioLinkPanel { state.advance() }
        case .finished:
            ProgressView()
        }
    }
}

#if DEBUG
#Preview("First time") {
    DecodingTutorialOverlay(mode: .firstTime, onFinished: {})
        .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#Preview("Replay") {
    DecodingTutorialOverlay(mode: .replay, onFinished: {})
        .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#endif
