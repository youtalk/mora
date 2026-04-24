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
        VStack(spacing: 8) {
            if state == .befriended {
                YokaiPortraitCorner(yokai: yokai).frame(width: 80, height: 80)
                Text(yokai.grapheme).font(.title2.weight(.bold))
                Text(yokai.ipa).font(.caption).foregroundStyle(.secondary)
            } else {
                Circle().fill(Color(white: 0.9)).frame(width: 80, height: 80)
                Text("?").font(.title)
            }
        }
        .padding()
        .background(Color(white: 0.98))
        .cornerRadius(16)
        .accessibilityLabel(
            state == .befriended
                ? Text("\(yokai.grapheme) yokai, befriended") : Text("Locked"))
    }
}
