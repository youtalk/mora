import SwiftUI

public struct WashiCardMorph: View {
    @Binding var progress: Double  // 0.0 ... 1.0

    public init(progress: Binding<Double>) {
        self._progress = progress
    }

    public var body: some View {
        let clamped = max(0, min(1, progress))
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 0.92, blue: 0.83),
                            Color(red: 0.90, green: 0.84, blue: 0.71),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(red: 0.55, green: 0.42, blue: 0.27), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.25 * clamped), radius: 12, x: 0, y: 6)
                .opacity(clamped)
                .scaleEffect(0.6 + clamped * 0.4)
        }
        .accessibilityHidden(true)
    }
}
