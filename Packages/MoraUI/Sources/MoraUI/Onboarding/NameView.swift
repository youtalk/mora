import SwiftUI

struct NameView: View {
    @Environment(\.moraStrings) private var strings
    @Binding var name: String
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            HStack {
                Spacer()
                Button(strings.nameSkip, action: onSkip)
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Ink.muted)
            }
            .padding(MoraTheme.Space.md)

            Spacer()

            Text(strings.namePrompt)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)

            TextField("Your name", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .padding(MoraTheme.Space.lg)
                .background(Color.white, in: .rect(cornerRadius: MoraTheme.Radius.card))
                .frame(maxWidth: 520)

            Spacer()

            HeroCTA(title: strings.nameCTA, action: onContinue)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
