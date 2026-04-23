import MoraCore
import MoraEngines
import SwiftUI

/// Drives the three overlay regions (category bar, score bar, coaching bubble)
/// from a single `PhonemeTrialAssessment`. Exposed as its own type so tests
/// can exercise the resolution logic without standing up a SwiftUI hierarchy.
public struct PronunciationFeedbackViewModel: Sendable {
    public let assessment: PhonemeTrialAssessment
    public let strings: MoraStrings

    public init(assessment: PhonemeTrialAssessment, strings: MoraStrings) {
        self.assessment = assessment
        self.strings = strings
    }

    /// Short "今の X は Y に寄ってたよ" banner for substitutions, or a drift
    /// nudge. Uses **kid-friendly** spellings resolved from `coachingKey`
    /// rather than raw IPA so a child sees "sh" / "s" instead of "ʃ" / "s".
    public var categoryText: String {
        switch assessment.label {
        case .matched, .unclear:
            return ""
        case .substitutedBy:
            guard let pair = Self.letters(forCoachingKey: assessment.coachingKey) else {
                return ""
            }
            return "今の \(pair.target) は \(pair.substitute) に寄ってたよ"
        case .driftedWithin:
            guard let pair = Self.letters(forCoachingKey: assessment.coachingKey) else {
                return ""
            }
            return "もう少し \(pair.target) らしい音に近づけよう"
        }
    }

    public var showScore: Bool {
        assessment.isReliable && assessment.score != nil
    }

    /// True when the overlay would render at least one visible element.
    /// Callers gate the whole overlay on this so `.unclear` trials (no
    /// category, no score, no coaching) do not paint an empty card.
    public var hasContent: Bool {
        !categoryText.isEmpty || showScore || !coachingText.isEmpty
    }

    public var scoreFraction: Double {
        guard let score = assessment.score else { return 0 }
        return Double(score) / 100.0
    }

    /// Japanese coaching prompt resolved from the L1 profile's strings
    /// catalog. Empty when the evaluator returned no `coachingKey`.
    public var coachingText: String {
        guard let key = assessment.coachingKey else { return "" }
        switch key {
        case "coaching.sh_sub_s": return strings.coachingShSubS
        case "coaching.sh_drift": return strings.coachingShDrift
        case "coaching.r_sub_l": return strings.coachingRSubL
        case "coaching.l_sub_r": return strings.coachingLSubR
        case "coaching.f_sub_h": return strings.coachingFSubH
        case "coaching.v_sub_b": return strings.coachingVSubB
        case "coaching.th_voiceless_sub_s": return strings.coachingThVoicelessSubS
        case "coaching.th_voiceless_sub_t": return strings.coachingThVoicelessSubT
        case "coaching.ae_sub_schwa": return strings.coachingAeSubSchwa
        default: return ""
        }
    }

    // MARK: - Private helpers

    /// Kid-friendly spelling pair for a coaching key. Keeps IPA out of the
    /// on-screen category bar: a beginning reader recognises "sh" / "s",
    /// not "ʃ" / "s".
    private struct LetterPair {
        let target: String
        let substitute: String
    }

    private static func letters(forCoachingKey key: String?) -> LetterPair? {
        guard let key else { return nil }
        switch key {
        case "coaching.sh_sub_s": return LetterPair(target: "sh", substitute: "s")
        case "coaching.sh_drift": return LetterPair(target: "sh", substitute: "sh")
        case "coaching.r_sub_l": return LetterPair(target: "r", substitute: "l")
        case "coaching.l_sub_r": return LetterPair(target: "l", substitute: "r")
        case "coaching.f_sub_h": return LetterPair(target: "f", substitute: "h")
        case "coaching.v_sub_b": return LetterPair(target: "v", substitute: "b")
        case "coaching.th_voiceless_sub_s": return LetterPair(target: "th", substitute: "s")
        case "coaching.th_voiceless_sub_t": return LetterPair(target: "th", substitute: "t")
        case "coaching.ae_sub_schwa": return LetterPair(target: "a", substitute: "u")
        default: return nil
        }
    }
}

/// Three-part feedback card shown after a pronunciation trial. Reads text
/// from a `PronunciationFeedbackViewModel` and calls `onAppearSpeak` with the
/// coaching line (if any) on appear so the child hears it in the same beat
/// they see it.
public struct PronunciationFeedbackOverlay: View {
    public let viewModel: PronunciationFeedbackViewModel
    public let onAppearSpeak: @Sendable (String) async -> Void

    public init(
        viewModel: PronunciationFeedbackViewModel,
        onAppearSpeak: @escaping @Sendable (String) async -> Void
    ) {
        self.viewModel = viewModel
        self.onAppearSpeak = onAppearSpeak
    }

    public var body: some View {
        VStack(spacing: 12) {
            if !viewModel.categoryText.isEmpty {
                Text(viewModel.categoryText)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            if viewModel.showScore {
                ProgressView(value: viewModel.scoreFraction)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 220)
                    .accessibilityLabel("score")
                    .accessibilityValue("\(Int(viewModel.scoreFraction * 100))")
            }
            if !viewModel.coachingText.isEmpty {
                Text(viewModel.coachingText)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: MoraTheme.Radius.card))
        .task {
            if !viewModel.coachingText.isEmpty {
                await onAppearSpeak(viewModel.coachingText)
            }
        }
    }
}
