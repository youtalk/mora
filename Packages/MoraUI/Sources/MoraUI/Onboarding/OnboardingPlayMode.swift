// Packages/MoraUI/Sources/MoraUI/Onboarding/OnboardingPlayMode.swift

/// Distinguishes the first-time gating run of an onboarding flow from
/// an on-demand replay. The replay variant must NOT mutate the
/// `UserDefaults` "seen" flag and may render a different terminal CTA
/// (e.g. a "Close" affordance instead of a "Start" call-to-action).
public enum OnboardingPlayMode: Equatable, Sendable {
    case firstTime
    case replay
}
