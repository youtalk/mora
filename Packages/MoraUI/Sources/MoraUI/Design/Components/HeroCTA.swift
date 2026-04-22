import SwiftUI

public struct HeroCTA: View {
    public let title: String
    public let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(MoraType.cta())
                .foregroundStyle(Color.white)
                .padding(.horizontal, MoraTheme.Space.xl)
                .padding(.vertical, MoraTheme.Space.md)
                .frame(minHeight: 88)
                .background(MoraTheme.Accent.orange, in: .capsule)
                .shadow(color: MoraTheme.Accent.orangeShadow, radius: 0, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}
