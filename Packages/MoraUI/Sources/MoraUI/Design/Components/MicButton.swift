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
                    Capsule()
                        .stroke(MoraTheme.Accent.teal, lineWidth: 6)
                        .frame(width: pillWidth + 32, height: pillHeight + 32)
                        .scaleEffect(pulse ? 1.12 : 1.0)
                        .opacity(pulse ? 0 : 1)
                        .animation(
                            .easeOut(duration: 0.9).repeatForever(autoreverses: false),
                            value: pulse
                        )
                }
                Capsule()
                    .fill(MoraTheme.Accent.orange)
                    .frame(width: pillWidth, height: pillHeight)
                iconRow
            }
            // Reserve a constant bounding box at every state so the
            // button doesn't reflow when the listening ripple appears or
            // the idle "はなす" label disappears — that reflow shoves
            // the transcript + counter rows below.
            .frame(width: pillWidth + 32, height: pillHeight + 32)
        }
        .buttonStyle(.plain)
        .disabled(state == .assessing)
        .onAppear { pulse = state == .listening }
        .onChange(of: state) { _, new in pulse = new == .listening }
        .accessibilityLabel(stateA11yLabel)
        .accessibilityHint(stateA11yHint)
        .accessibilityAddTraits(state == .assessing ? .isStaticText : [])
    }

    /// Outer width of the orange pill. Idle state shows mic + "はなす",
    /// other states show just the icon — but the pill stays the same
    /// size so the button doesn't jump on state change.
    private var pillWidth: CGFloat { 216 }
    private var pillHeight: CGFloat { 112 }

    @ViewBuilder
    private var iconRow: some View {
        HStack(spacing: MoraTheme.Space.sm) {
            Image(systemName: state.iconName)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Color.white)
            if state == .idle {
                Text(strings.micButtonLabel)
                    .font(MoraType.heading())
                    .foregroundStyle(Color.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
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

    /// VoiceOver hint per state, sourced from `MoraStrings` so the JP-first
    /// build does not emit English. Empty for `.assessing` (button disabled,
    /// nothing for the user to do).
    private var stateA11yHint: String {
        switch state {
        case .idle: return strings.micButtonHintTapToStart
        case .listening: return strings.micButtonHintTapToStop
        case .assessing: return ""
        }
    }

    @State private var pulse: Bool = false
}
