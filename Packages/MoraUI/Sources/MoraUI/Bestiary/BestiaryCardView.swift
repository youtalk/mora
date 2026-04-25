import MoraCore
import SwiftUI

public struct BestiaryCardView: View {
    public enum CardState { case befriended, locked }
    let yokai: YokaiDefinition
    let state: CardState

    public init(yokai: YokaiDefinition, state: CardState) {
        self.yokai = yokai
        self.state = state
    }

    public var body: some View {
        VStack(spacing: MoraTheme.Space.sm) {
            if state == .befriended {
                YokaiPortraitCorner(yokai: yokai)
                    .frame(width: 160, height: 160)
                Text(yokai.grapheme)
                    .font(MoraType.heading())
                    .foregroundStyle(MoraTheme.Ink.primary)
                Text(yokai.ipa)
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Ink.muted)
            } else {
                Circle()
                    .fill(MoraTheme.Background.cream.opacity(0.5))
                    .frame(width: 160, height: 160)
                    .overlay(
                        Text("?")
                            .font(MoraType.heroWord(80))
                            .foregroundStyle(MoraTheme.Ink.muted)
                    )
                Text(" ").font(MoraType.heading())
                Text(" ").font(MoraType.label())
            }
        }
        .padding(MoraTheme.Space.md)
        .frame(maxWidth: .infinity)
        .background(
            MoraTheme.Background.cream,
            in: .rect(cornerRadius: MoraTheme.Radius.card)
        )
        .accessibilityLabel(
            state == .befriended
                ? Text("\(yokai.grapheme) yokai, befriended") : Text("Locked"))
    }
}
