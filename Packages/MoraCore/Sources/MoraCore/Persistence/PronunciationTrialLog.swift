import Foundation
import SwiftData

/// Per-trial shadow-mode log row. Populated by `SwiftDataPronunciationTrialLogger`
/// on every evaluator invocation while Engine B is bundled. Capped at 1000
/// rows by `PronunciationTrialRetentionPolicy`.
///
/// `engineALabel`, `engineAFeaturesJSON`, and `engineBLabel` are stored as
/// JSON strings (via `JSONEncoder` at write time) because SwiftData prefers
/// scalar fields. Decoding is on demand.
@Model
public final class PronunciationTrialLog {
    public var timestamp: Date
    public var wordSurface: String
    public var targetPhonemeIPA: String
    public var engineALabel: String
    public var engineAScore: Int?
    public var engineAFeaturesJSON: String
    public var engineBState: String
    public var engineBLabel: String?
    public var engineBScore: Int?
    public var engineBLatencyMs: Int?

    public init(
        timestamp: Date,
        wordSurface: String,
        targetPhonemeIPA: String,
        engineALabel: String,
        engineAScore: Int?,
        engineAFeaturesJSON: String,
        engineBState: String,
        engineBLabel: String?,
        engineBScore: Int?,
        engineBLatencyMs: Int?
    ) {
        self.timestamp = timestamp
        self.wordSurface = wordSurface
        self.targetPhonemeIPA = targetPhonemeIPA
        self.engineALabel = engineALabel
        self.engineAScore = engineAScore
        self.engineAFeaturesJSON = engineAFeaturesJSON
        self.engineBState = engineBState
        self.engineBLabel = engineBLabel
        self.engineBScore = engineBScore
        self.engineBLatencyMs = engineBLatencyMs
    }
}
