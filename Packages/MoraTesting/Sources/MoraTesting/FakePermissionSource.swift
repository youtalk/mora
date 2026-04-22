import Foundation
import MoraEngines

@MainActor
public final class FakePermissionSource: PermissionSource {
    public var mic: PermissionOutcome
    public var speech: PermissionOutcome

    /// Set to control what `requestMic()` returns next. Falls back to `mic`
    /// if nil.
    public var nextMicResult: PermissionOutcome?
    public var nextSpeechResult: PermissionOutcome?

    public init(
        mic: PermissionOutcome = .notDetermined,
        speech: PermissionOutcome = .notDetermined
    ) {
        self.mic = mic
        self.speech = speech
    }

    public func currentMic() -> PermissionOutcome { mic }
    public func currentSpeech() -> PermissionOutcome { speech }

    public func requestMic() async -> PermissionOutcome {
        let r = nextMicResult ?? mic
        mic = r
        return r
    }
    public func requestSpeech() async -> PermissionOutcome {
        let r = nextSpeechResult ?? speech
        speech = r
        return r
    }
}
