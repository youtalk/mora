import MoraEngines
import SwiftUI

private struct MLXWarmupStateKey: EnvironmentKey {
    static let defaultValue: MLXWarmupState? = nil
}

public extension EnvironmentValues {
    /// App-target-owned observable tracking the Engine B (wav2vec2 CoreML)
    /// warmup. `nil` in previews and tests that don't wire it; views should
    /// treat that as "don't gate" (backward compatible with the pre-warmup
    /// flow).
    var mlxWarmupState: MLXWarmupState? {
        get { self[MLXWarmupStateKey.self] }
        set { self[MLXWarmupStateKey.self] = newValue }
    }
}
