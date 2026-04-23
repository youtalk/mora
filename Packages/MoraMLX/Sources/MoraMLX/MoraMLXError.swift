import Foundation

public enum MoraMLXError: Error, Sendable, Equatable {
    /// The bundled CoreML model was not found at load time. The app falls
    /// back to bare Engine A.
    case modelNotBundled
    /// The model loaded but an inference pass failed at runtime.
    case inferenceFailed(String)
    /// `phoneme-labels.json` is missing or cannot be decoded.
    case inventoryUnavailable
}
