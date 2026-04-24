import SwiftUI

public struct CurriculumCompleteView: View {
    @Environment(\.moraStrings) private var strings
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()
            Text("You befriended all five sound-friends!")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)

            NavigationLink(value: "bestiary") {
                Label("Open your Sound-Friend Register", systemImage: "book.closed.fill")
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding(MoraTheme.Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MoraTheme.Background.page.ignoresSafeArea())
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
    }
}
