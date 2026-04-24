import SwiftUI

public struct FriendshipGaugeHUD: View {
    let percent: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(percent: Double) { self.percent = percent }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(white: 0.94))
                RoundedRectangle(cornerRadius: 9)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.40, green: 0.75, blue: 0.70), Color(red: 0.55, green: 0.85, blue: 0.80),
                            ],
                            startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * percent)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: percent)
            }
            .overlay(
                Text("\(Int(round(percent * 100)))%")
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8),
                alignment: .trailing
            )
            .accessibilityElement()
            .accessibilityLabel("Friendship")
            .accessibilityValue("\(Int(round(percent * 100))) percent")
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        FriendshipGaugeHUD(percent: 0.12).frame(width: 200, height: 18)
        FriendshipGaugeHUD(percent: 0.48).frame(width: 200, height: 18)
        FriendshipGaugeHUD(percent: 1.00).frame(width: 200, height: 18)
    }.padding()
}
