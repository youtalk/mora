import MoraCore
import MoraEngines
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// NOTE: DecodeActivityView is superseded by DecodeBoardView (PR 5 / Task 26).
// This file is a compile-safe placeholder kept so SessionContainerView still
// references a valid type until the PR 5 integration replaces both.
struct DecodeActivityView: View {
    @Environment(\.moraStrings) private var strings
    let orchestrator: SessionOrchestrator
    let uiMode: SessionUIMode
    @Binding var feedback: FeedbackState
    let speechEngine: SpeechEngine?
    let speech: SpeechController?

    @State private var micState: MicUIState = .idle
    @State private var shakeAmount: CGFloat = 0
    @State private var shakeResetTask: Task<Void, Never>?
    @State private var lastHeard: String = ""

    var body: some View {
        ProgressView()
            .onChange(of: feedback) { _, new in
                if new == .wrong {
                    shakeResetTask?.cancel()
                    withAnimation(.linear(duration: 0.6)) { shakeAmount = 1 }
                    shakeResetTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        guard !Task.isCancelled else { return }
                        shakeAmount = 0
                    }
                }
                #if canImport(UIKit)
                switch new {
                case .correct: UINotificationFeedbackGenerator().notificationOccurred(.success)
                case .wrong: UINotificationFeedbackGenerator().notificationOccurred(.error)
                case .none: break
                }
                #endif
            }
    }
}
