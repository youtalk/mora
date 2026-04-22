import SwiftUI

public enum FeedbackState: Equatable, Sendable {
    case none
    case correct
    case wrong
}

public struct FeedbackOverlay: View {
    public let state: FeedbackState
    public init(state: FeedbackState) { self.state = state }

    public var body: some View {
        ZStack {
            switch state {
            case .none:
                EmptyView()
            case .correct:
                MoraTheme.Feedback.correct.opacity(0.30)
                    .ignoresSafeArea()
                Image(systemName: "checkmark.circle.fill")
                    .resizable().scaledToFit()
                    .frame(width: 140, height: 140)
                    .foregroundStyle(MoraTheme.Feedback.correct)
            case .wrong:
                RoundedRectangle(cornerRadius: MoraTheme.Radius.card)
                    .strokeBorder(MoraTheme.Feedback.wrong, lineWidth: 8)
                    .padding(MoraTheme.Space.md)
                    .ignoresSafeArea()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }
}
