import Foundation
import MoraCore

/// Engine B — CoreML-backed `PronunciationEvaluator`. Given an `AudioClip`,
/// obtains a phoneme posterior from the provider, forced-aligns the
/// expected phoneme sequence, scores the target region with GOP, and
/// classifies the argmax against the learner's L1 interference pairs.
public struct PhonemeModelPronunciationEvaluator: PronunciationEvaluator {
    public let provider: any PhonemePosteriorProvider
    public let aligner: ForcedAligner
    public let scorer: GOPScorer
    public let inventory: PhonemeInventory
    public let l1Profile: any L1Profile
    public let timeout: Duration

    public init(
        provider: any PhonemePosteriorProvider,
        aligner: ForcedAligner,
        scorer: GOPScorer,
        inventory: PhonemeInventory,
        l1Profile: any L1Profile,
        timeout: Duration = .milliseconds(1000)
    ) {
        self.provider = provider
        self.aligner = aligner
        self.scorer = scorer
        self.inventory = inventory
        self.l1Profile = l1Profile
        self.timeout = timeout
    }

    public func supports(target: Phoneme, in word: Word) -> Bool {
        inventory.supportedPhonemeIPA.contains(target.ipa)
    }

    public func evaluate(
        audio: AudioClip,
        expected: Word,
        targetPhoneme: Phoneme,
        asr: ASRResult
    ) async -> PhonemeTrialAssessment {
        if !supports(target: targetPhoneme, in: expected) {
            return unreliable(targetPhoneme, reason: "unsupported")
        }

        let capturedProvider = provider
        let posterior = await withTimeout(timeout) { () async throws -> PhonemePosterior in
            try await capturedProvider.posterior(for: audio)
        }
        guard let posterior, posterior.frameCount > 0 else {
            return unreliable(targetPhoneme, reason: "provider_unavailable")
        }

        let alignments = aligner.align(posterior: posterior, phonemes: expected.phonemes)
        guard let alignment = locateAlignment(for: targetPhoneme, in: expected, alignments: alignments)
        else {
            return unreliable(targetPhoneme, reason: "no_alignment")
        }

        if Double(alignment.averageLogProb) < scorer.reliabilityThreshold {
            return unreliable(targetPhoneme, reason: "low_confidence")
        }

        guard let targetColumn = inventory.ipaToColumn[targetPhoneme.ipa] else {
            return unreliable(targetPhoneme, reason: "inventory_drift")
        }
        let range = alignment.startFrame..<alignment.endFrame
        let gopValue = scorer.gop(posterior: posterior, range: range, targetColumn: targetColumn)
        let score = scorer.score0to100(gop: gopValue)

        let argmaxIPA = argmaxIPA(in: posterior, range: range)
        let label: PhonemeAssessmentLabel
        var coachingKey: String?

        if argmaxIPA == targetPhoneme.ipa {
            label = .matched
        } else if let sub = argmaxIPA, isKnownSubstitution(target: targetPhoneme, substitute: sub) {
            label = .substitutedBy(Phoneme(ipa: sub))
            coachingKey = CoachingKeyResolver.substitution(target: targetPhoneme.ipa, substitute: sub)
        } else {
            label = .unclear
        }

        let features: [String: Double] = [
            "gop": gopValue,
            "avgLogProb": Double(alignment.averageLogProb),
            "frameCount": Double(range.count),
        ]

        return PhonemeTrialAssessment(
            targetPhoneme: targetPhoneme,
            label: label,
            score: label == .unclear ? nil : score,
            coachingKey: coachingKey,
            features: features,
            isReliable: label != .unclear
        )
    }

    private func locateAlignment(
        for target: Phoneme,
        in word: Word,
        alignments: [PhonemeAlignment]
    ) -> PhonemeAlignment? {
        let matches = alignments.enumerated().filter { $0.element.phoneme.ipa == target.ipa }
        if matches.isEmpty { return nil }
        // Prefer the occurrence whose position matches the word's phoneme
        // list index of the first target-IPA entry. When targetPhoneme is
        // set to one of several repeats, the first match is our best guess
        // without an explicit curriculum-provided index.
        return matches.first?.element
    }

    private func argmaxIPA(in posterior: PhonemePosterior, range: Range<Int>) -> String? {
        if range.isEmpty { return nil }
        var totals = Array(repeating: Float(0), count: posterior.phonemeCount)
        for t in range {
            let row = posterior.logProbabilities[t]
            for (i, v) in row.enumerated() {
                totals[i] += v
            }
        }
        var bestIndex = 0
        var bestValue = totals[0]
        for i in 1..<totals.count where totals[i] > bestValue {
            bestValue = totals[i]
            bestIndex = i
        }
        return posterior.phonemeLabels[bestIndex]
    }

    private func isKnownSubstitution(target: Phoneme, substitute: String) -> Bool {
        for pair in l1Profile.interferencePairs where pair.from == target {
            if pair.to.ipa == substitute { return true }
        }
        return CoachingKeyResolver.substitution(target: target.ipa, substitute: substitute) != nil
    }

    private func unreliable(_ target: Phoneme, reason: String) -> PhonemeTrialAssessment {
        PhonemeTrialAssessment(
            targetPhoneme: target,
            label: .unclear,
            score: nil,
            coachingKey: nil,
            features: ["reason": reason == "unsupported" ? 0 : 1],
            isReliable: false
        )
    }
}
