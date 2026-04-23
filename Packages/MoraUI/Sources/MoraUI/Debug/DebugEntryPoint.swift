#if DEBUG
import SwiftUI

/// Attaches a hidden 5-tap gesture to any view. Every tap on the
/// attached content is timestamped; taps older than `window` seconds
/// are discarded, and once `threshold` fresh taps have accumulated,
/// a NavigationLink to `PronunciationRecorderView` is revealed in an
/// overlay below the content. Activation is sticky — once the link is
/// shown it stays visible for the lifetime of the view; there is no
/// deactivation path. Taps outside the attached content are not seen
/// by this modifier and therefore have no effect on the counter.
public struct DebugFixtureRecorderEntryModifier: ViewModifier {

    @State private var taps: [Date] = []
    @State private var isActivated = false
    private let threshold: Int = 5
    private let window: TimeInterval = 3

    public init() {}

    public func body(content: Content) -> some View {
        VStack(spacing: 8) {
            content
                .contentShape(Rectangle())
                .onTapGesture { registerTap() }
            if isActivated {
                NavigationLink("Fixture Recorder") {
                    PronunciationRecorderView()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
    }

    private func registerTap() {
        let now = Date()
        taps.append(now)
        taps = taps.filter { now.timeIntervalSince($0) <= window }
        if taps.count >= threshold {
            isActivated = true
            taps.removeAll()
        }
    }
}

public extension View {
    func debugFixtureRecorderEntry() -> some View {
        modifier(DebugFixtureRecorderEntryModifier())
    }
}
#endif
