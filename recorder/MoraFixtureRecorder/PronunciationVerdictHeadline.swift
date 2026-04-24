import MoraCore
import MoraEngines
import MoraFixtures

public struct PronunciationVerdictHeadlineContent: Equatable, Sendable {
    public enum Tone: Sendable { case pass, fail, warn }
    public let tone: Tone
    public let title: String
    public let subtitle: String?
}

public enum PronunciationVerdictHeadline {

    /// Maps (pattern expectedLabel + substitute) × (assessment label +
    /// isReliable) into the 7-case display headline from the spec
    /// §5.1, plus the isReliable prefix.
    public static func make(
        pattern: FixturePattern,
        assessment: PhonemeTrialAssessment
    ) -> PronunciationVerdictHeadlineContent {
        // Unreliable short-circuits — the label is still shown but the
        // tone drops to .warn and the title is prefixed.
        if !assessment.isReliable {
            let core = coreHeadline(pattern: pattern, assessment: assessment)
            return PronunciationVerdictHeadlineContent(
                tone: .warn,
                title: "unreliable · \(core.title)",
                subtitle: core.subtitle
            )
        }
        return coreHeadline(pattern: pattern, assessment: assessment)
    }

    private static func coreHeadline(
        pattern: FixturePattern,
        assessment: PhonemeTrialAssessment
    ) -> PronunciationVerdictHeadlineContent {
        switch assessment.label {
        case .unclear:
            return .init(tone: .warn, title: "audio unclear",
                         subtitle: "re-record longer/louder")

        case .matched:
            switch pattern.expectedLabel {
            case .matched:
                return .init(tone: .pass, title: "matched", subtitle: nil)
            case .substitutedBy:
                let sub = pattern.substitutePhonemeIPA ?? "?"
                return .init(
                    tone: .fail, title: "matched",
                    subtitle: "expected substitution /\(sub)/ — re-record with clearer /\(sub)/"
                )
            case .driftedWithin:
                return .init(tone: .fail, title: "matched",
                             subtitle: "expected drift")
            }

        case .substitutedBy(let heard):
            switch pattern.expectedLabel {
            case .matched:
                return .init(
                    tone: .fail, title: "heard /\(heard.ipa)/",
                    subtitle: "expected matched /\(pattern.targetPhonemeIPA)/"
                )
            case .substitutedBy:
                let expected = pattern.substitutePhonemeIPA ?? "?"
                if heard.ipa == expected {
                    return .init(
                        tone: .pass, title: "heard /\(heard.ipa)/",
                        subtitle: "matches expected substitution"
                    )
                } else {
                    return .init(
                        tone: .fail, title: "heard /\(heard.ipa)/",
                        subtitle: "expected substitution /\(expected)/"
                    )
                }
            case .driftedWithin:
                return .init(
                    tone: .fail, title: "heard /\(heard.ipa)/",
                    subtitle: "expected drift"
                )
            }

        case .driftedWithin:
            switch pattern.expectedLabel {
            case .driftedWithin:
                return .init(tone: .pass, title: "drifted", subtitle: nil)
            default:
                return .init(tone: .fail, title: "drifted", subtitle: nil)
            }
        }
    }
}
