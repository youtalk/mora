import Foundation
import MoraCore

public struct ASRResult: Hashable, Codable, Sendable {
    public let transcript: String
    public let confidence: Double

    public init(transcript: String, confidence: Double) {
        self.transcript = transcript
        self.confidence = confidence
    }
}

public enum TrialErrorKind: String, Hashable, Codable, Sendable, CaseIterable {
    case none
    case substitution
    case omission
    case insertion
    case unclear
}

public struct TrialAssessment: Hashable, Codable, Sendable {
    public let expected: Word
    public let heard: String?
    public let correct: Bool
    public let errorKind: TrialErrorKind
    public let l1InterferenceTag: String?
    public let phoneme: PhonemeTrialAssessment?

    public init(
        expected: Word, heard: String?, correct: Bool,
        errorKind: TrialErrorKind, l1InterferenceTag: String?,
        phoneme: PhonemeTrialAssessment? = nil
    ) {
        self.expected = expected
        self.heard = heard
        self.correct = correct
        self.errorKind = errorKind
        self.l1InterferenceTag = l1InterferenceTag
        self.phoneme = phoneme
    }
}
