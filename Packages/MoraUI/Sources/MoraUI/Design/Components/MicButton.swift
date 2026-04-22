import SwiftUI

public enum MicButtonState: Equatable, Sendable {
    case idle
    case listening
    case assessing
}

public struct MicButton: View {
    public let state: MicButtonState
    public let action: () -> Void

    public init(state: MicButtonState, action: @escaping () -> Void) {
        self.state = state
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                if state == .listening {
                    Circle()
                        .stroke(MoraTheme.Accent.teal, lineWidth: 6)
                        .frame(width: 128, height: 128)
                        .scaleEffect(pulse ? 1.12 : 1.0)
                        .opacity(pulse ? 0 : 1)
                        .animation(
                            .easeOut(duration: 0.9).repeatForever(autoreverses: false),
                            value: pulse
                        )
                }
                Circle()
                    .fill(MoraTheme.Accent.orange)
                    .frame(width: 96, height: 96)
                    .shadow(color: MoraTheme.Accent.orangeShadow, radius: 0, x: 0, y: 5)
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(state == .assessing)
        .onAppear { pulse = state == .listening }
        .onChange(of: state) { _, new in pulse = new == .listening }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(state == .assessing ? .isStaticText : [])
    }

    @State private var pulse: Bool = false

    private var icon: String {
        switch state {
        case .idle: return "mic.fill"
        case .listening: return "waveform"
        case .assessing: return "ellipsis"
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .idle: return "Start speaking"
        case .listening: return "Listening"
        case .assessing: return "Checking your answer"
        }
    }

    private var accessibilityHint: String {
        switch state {
        case .idle: return "Tap to start recording"
        case .listening: return "Tap to stop recording"
        case .assessing: return ""
        }
    }
}
