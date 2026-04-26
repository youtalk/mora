import MoraEngines
import SwiftUI

private struct SpeechEnginesWarmupKey: EnvironmentKey {
    static let defaultValue: SpeechEnginesWarmup? = nil
}

public extension EnvironmentValues {
    /// App-target-owned observable holding the pre-warmed Apple speech
    /// + TTS engines. `nil` in previews and tests that don't wire it;
    /// `SessionContainerView.bootstrap` falls back to constructing
    /// fresh instances in that case so the view stays self-contained
    /// for non-app-host contexts.
    var speechEnginesWarmup: SpeechEnginesWarmup? {
        get { self[SpeechEnginesWarmupKey.self] }
        set { self[SpeechEnginesWarmupKey.self] = newValue }
    }
}
