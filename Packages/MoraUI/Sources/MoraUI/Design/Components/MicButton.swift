import SwiftUI

public enum MicButtonState: Equatable, Sendable {
    case idle
    case listening
    case assessing

    public var iconName: String {
        switch self {
        case .idle: return "mic.fill"
        case .listening: return "waveform"
        case .assessing: return "ellipsis"
        }
    }

    public var accessibilityLabel: String {
        switch self {
        case .idle: return "Start speaking"
        case .listening: return "Listening"
        case .assessing: return "Checking your answer"
        }
    }

    public var accessibilityHint: String {
        switch self {
        case .idle: return "Tap to start recording"
        case .listening: return "Tap to stop recording"
        case .assessing: return ""
        }
    }
}

/// View-level state for the mic flow. Unlike `MicButtonState` it carries the
/// partial-transcript text, which the decoding/sentence views surface below the
/// mic button while the recognizer streams intermediate results.
public enum MicUIState: Equatable, Sendable {
    case idle
    case listening(partialText: String)
    case assessing

    public var buttonState: MicButtonState {
        switch self {
        case .idle: return .idle
        case .listening: return .listening
        case .assessing: return .assessing
        }
    }
}

public struct MicButton: View {
    @Environment(\.moraStrings) private var strings
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
                Image(systemName: state.iconName)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            // Reserve the full 128pt bounding box at every state so the
            // button doesn't expand by 32pt when the listening ripple
            // appears — that expansion shoved the transcript + counter
            // rows down by one line each time the learner tapped the mic.
            .frame(width: 128, height: 128)
        }
        .buttonStyle(.plain)
        .disabled(state == .assessing)
        .onAppear { pulse = state == .listening }
        .onChange(of: state) { _, new in pulse = new == .listening }
        .accessibilityLabel(stateA11yLabel)
        .accessibilityHint(state.accessibilityHint)
        .accessibilityAddTraits(state == .assessing ? .isStaticText : [])
    }

    /// Pick a localized label from `strings` based on the current state so
    /// VoiceOver announces "listening", "checking", etc. rather than a
    /// generic "mic" label. Falls back to `a11yMicButton` if a state ever
    /// lacks a mapping.
    private var stateA11yLabel: String {
        switch state {
        case .idle: return strings.a11yMicButton
        case .listening: return strings.micListening
        case .assessing: return strings.micAssessing
        }
    }

    @State private var pulse: Bool = false
}
