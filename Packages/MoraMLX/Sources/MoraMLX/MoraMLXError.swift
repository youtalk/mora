import Foundation

public enum MoraMLXError: Error, Sendable, Equatable {
    /// The bundled CoreML model was not found at load time. The app falls
    /// back to bare Engine A.
    case modelNotBundled
    /// The CoreML model file exists in the bundle but `MLModel(contentsOf:)`
    /// failed to open it (e.g., a placeholder directory is present while
    /// the real LFS-tracked `.mlmodelc` has not yet been committed, or the
    /// compiled model is corrupted). The app falls back to bare Engine A.
    case modelLoadFailed(String)
    /// The model loaded but an inference pass failed at runtime.
    case inferenceFailed(String)
    /// `phoneme-labels.json` is missing or cannot be decoded.
    case inventoryUnavailable
}
