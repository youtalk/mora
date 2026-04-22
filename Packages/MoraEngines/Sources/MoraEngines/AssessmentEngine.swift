import Foundation
import MoraCore

public struct AssessmentEngine: Sendable {
    public let l1Profile: any L1Profile
    public let leniency: Double

    public init(l1Profile: any L1Profile, leniency: Double = 0.5) {
        self.l1Profile = l1Profile
        self.leniency = leniency
    }

    public func assess(expected: Word, asr: ASRResult) -> TrialAssessment {
        let normalized = normalize(asr.transcript)
        let target = expected.surface.lowercased()

        if normalized.isEmpty {
            return TrialAssessment(
                expected: expected, heard: asr.transcript,
                correct: false, errorKind: .omission,
                l1InterferenceTag: nil
            )
        }
        if normalized == target {
            return TrialAssessment(
                expected: expected, heard: asr.transcript,
                correct: true, errorKind: .none,
                l1InterferenceTag: nil
            )
        }

        let (errorKind, l1Tag) = classify(
            expected: expected,
            heardNormalized: normalized
        )
        return TrialAssessment(
            expected: expected, heard: asr.transcript,
            correct: false, errorKind: errorKind,
            l1InterferenceTag: l1Tag
        )
    }

    private func normalize(_ s: String) -> String {
        s.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?"))
    }

    private func classify(expected: Word, heardNormalized: String) -> (TrialErrorKind, String?) {
        // v1 heuristic: compare expected phoneme count to heard character count.
        // Each char of free-text ASR output is treated as one phonemic unit; a
        // digraph like "sh" decoded as "s" then registers as a substitution
        // (3 phonemes ↔ 3 chars), not an omission of one letter.
        let expectedUnits = expected.phonemes.count
        let heardUnits = heardNormalized.count
        let diff = heardUnits - expectedUnits
        let kind: TrialErrorKind
        if diff > 0 {
            kind = .insertion
        } else if diff < 0 {
            kind = .omission
        } else {
            kind = .substitution
        }
        return (kind, nil)  // L1 tagging added in Task 17
    }
}
