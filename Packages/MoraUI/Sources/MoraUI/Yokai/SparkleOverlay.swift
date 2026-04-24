import SwiftUI

public struct SparkleOverlay: View {
    let trigger: AnyHashable
    @State private var show = false

    public init(trigger: AnyHashable) { self.trigger = trigger }

    public var body: some View {
        ZStack {
            if show {
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 6, height: 6)
                        .offset(
                            x: CGFloat.random(in: -40...40),
                            y: CGFloat.random(in: -40...40)
                        )
                        .opacity(show ? 0 : 1)
                        .animation(.easeOut(duration: 0.6).delay(Double(i) * 0.05), value: show)
                }
            }
        }
        .onChange(of: trigger) { _, _ in
            show = false
            withAnimation(.easeOut(duration: 0.6)) { show = true }
        }
        .accessibilityHidden(true)
    }
}
