import Foundation
import Observation

@Observable
@MainActor
final class YokaiIntroState {
    enum Step: Equatable, CaseIterable {
        case concept, todayYokai, sessionShape, progress, finished
    }

    var step: Step = .concept

    static let onboardedKey = "tech.reenable.Mora.yokaiIntroSeen"

    func advance() {
        switch step {
        case .concept: step = .todayYokai
        case .todayYokai: step = .sessionShape
        case .sessionShape: step = .progress
        case .progress: step = .finished
        case .finished: break
        }
    }

    func finalize(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: Self.onboardedKey)
    }
}

import MoraCore
import MoraEngines
import SwiftUI

public struct YokaiIntroFlow: View {
    @State private var state = YokaiIntroState()
    private let mode: OnboardingPlayMode
    private let onFinished: () -> Void
    @State private var store: BundledYokaiStore? = try? BundledYokaiStore()
    @State private var player: any YokaiClipPlayer = AVFoundationYokaiClipPlayer()

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
                    state.finalize()
                }
                player.stop()
                onFinished()
            }
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch state.step {
        case .concept:
            YokaiConceptPanel(store: store) { state.advance() }
        case .todayYokai:
            TodaysYokaiPanel(store: store, player: player) { state.advance() }
        case .sessionShape:
            SessionShapePanel { state.advance() }
        case .progress:
            ProgressPanel(store: store, mode: mode) { state.advance() }
        case .finished:
            ProgressView()
        }
    }
}

#if DEBUG
#Preview("First time") {
    YokaiIntroFlow(mode: .firstTime, onFinished: {})
        .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#Preview("Replay") {
    YokaiIntroFlow(mode: .replay, onFinished: {})
        .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#endif
