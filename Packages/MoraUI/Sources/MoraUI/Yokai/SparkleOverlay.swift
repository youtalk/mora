import SwiftUI

public struct SparkleOverlay: View {
    let trigger: AnyHashable
    @State private var visible = false
    @State private var offsets: [(CGFloat, CGFloat)] = SparkleOverlay.makeOffsets()
    @State private var task: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(trigger: AnyHashable) { self.trigger = trigger }

    public var body: some View {
        ZStack {
            ForEach(0..<offsets.count, id: \.self) { i in
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 6, height: 6)
                    .offset(x: offsets[i].0, y: offsets[i].1)
                    .opacity(visible ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(Double(i) * 0.05), value: visible)
            }
        }
        .onChange(of: trigger) { _, _ in
            guard !reduceMotion else { return }
            task?.cancel()
            offsets = SparkleOverlay.makeOffsets()
            visible = true
            task = Task { @MainActor in
                // Hold visibility long enough for every staggered circle to reach opacity 1.
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                visible = false
            }
        }
        .onDisappear { task?.cancel() }
        .accessibilityHidden(true)
    }

    private static func makeOffsets() -> [(CGFloat, CGFloat)] {
        (0..<6).map { _ in (CGFloat.random(in: -40...40), CGFloat.random(in: -40...40)) }
    }
}
