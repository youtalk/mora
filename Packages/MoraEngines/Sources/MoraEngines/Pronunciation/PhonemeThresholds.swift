import Foundation

/// Named acoustic feature. Each primary/drift entry refers to one of these.
/// Values are exposed as strings in `PhonemeTrialAssessment.features` — the
/// `key` property is the dictionary key used there so logging and scoring
/// refer to the same name.
public enum AcousticFeature: String, Sendable, Hashable {
    case spectralCentroidHz
    case highLowEnergyRatio
    case zeroCrossingRateVariance
    case voicingOnsetTimeMs
    case onsetBurstSlope
    case spectralFlatness
    case formantF1Hz
    case formantF2Hz
    case formantF3Hz

    public var key: String { rawValue }
}

/// Literature-derived centroids and decision boundary for a substitution pair.
public struct SubstitutionThresholds: Sendable, Hashable {
    public let feature: AcousticFeature
    /// Feature-space value that corresponds to a clearly-correct production.
    public let targetCentroid: Double
    /// Feature-space value that corresponds to the substitute phoneme.
    public let substituteCentroid: Double
    /// Feature-space value that marks the categorical decision boundary.
    /// Substitute is chosen when the measured feature is on the
    /// substitute side of this boundary.
    public let boundary: Double
}

/// Literature-derived centroid + minimum-reliable value for a drift feature.
public struct DriftThresholds: Sendable, Hashable {
    public let feature: AcousticFeature
    public let targetCentroid: Double
    public let minReliable: Double
}

public enum PhonemeThresholds {

    /// Returns the primary substitution threshold for (target → substitute),
    /// or nil if the pair is not one Engine A knows how to score.
    public static func primary(for targetIPA: String, against substituteIPA: String)
        -> SubstitutionThresholds?
    {
        switch (targetIPA, substituteIPA) {
        case ("ʃ", "s"):
            return SubstitutionThresholds(
                feature: .spectralCentroidHz,
                targetCentroid: 3_000, substituteCentroid: 6_500, boundary: 4_500
            )
        case ("r", "l"):
            return SubstitutionThresholds(
                feature: .formantF3Hz,
                targetCentroid: 1_700, substituteCentroid: 3_000, boundary: 2_300
            )
        case ("l", "r"):
            return SubstitutionThresholds(
                feature: .formantF3Hz,
                targetCentroid: 3_000, substituteCentroid: 1_700, boundary: 2_300
            )
        case ("f", "h"):
            return SubstitutionThresholds(
                feature: .highLowEnergyRatio,
                targetCentroid: 1.4, substituteCentroid: 0.5, boundary: 0.9
            )
        case ("v", "b"):
            return SubstitutionThresholds(
                feature: .voicingOnsetTimeMs,
                targetCentroid: -30, substituteCentroid: 15, boundary: -5
            )
        case ("θ", "s"):
            return SubstitutionThresholds(
                feature: .spectralCentroidHz,
                targetCentroid: 4_500, substituteCentroid: 6_500, boundary: 5_500
            )
        case ("θ", "t"):
            return SubstitutionThresholds(
                feature: .onsetBurstSlope,
                targetCentroid: 0.4, substituteCentroid: 1.5, boundary: 0.8
            )
        case ("æ", "ʌ"):
            return SubstitutionThresholds(
                feature: .formantF1Hz,
                targetCentroid: 700, substituteCentroid: 580, boundary: 590
            )
        case ("ʌ", "æ"):
            return SubstitutionThresholds(
                feature: .formantF1Hz,
                targetCentroid: 580, substituteCentroid: 700, boundary: 590
            )
        default:
            return nil
        }
    }

    /// Returns the drift threshold for a target phoneme, or nil if not scored.
    public static func drift(for targetIPA: String) -> DriftThresholds? {
        switch targetIPA {
        case "ʃ":
            return DriftThresholds(
                feature: .formantF2Hz,
                targetCentroid: 2_000,
                minReliable: 1_700
            )
        default:
            return nil
        }
    }
}
