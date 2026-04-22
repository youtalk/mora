import SwiftUI

struct WelcomeView: View {
    @Environment(\.moraStrings) private var strings
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()
            Text("Mora")
                .font(.system(size: 120, weight: .heavy, design: .rounded))
                .foregroundStyle(MoraTheme.Accent.orange)
            Text(strings.welcomeTitle)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, MoraTheme.Space.xl)
            Spacer()
            HeroCTA(title: strings.welcomeCTA, action: onContinue)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
