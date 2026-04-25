import SwiftUI

/// Terminal screen shown once every yokai in the v1 ladder has been
/// befriended. Leaves the navigation bar visible so the learner can swipe
/// / tap back to Home; the forward CTA opens the Sound-Friend Register.
public struct CurriculumCompleteView: View {
    @Environment(\.moraStrings) private var strings

    public init() {}

    public var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()
            Text("You befriended all five sound-friends!")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)

            NavigationLink(value: "bestiary") {
                Label(strings.bestiaryLinkLabel, systemImage: "book.closed.fill")
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding(MoraTheme.Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MoraTheme.Background.page.ignoresSafeArea())
    }
}
