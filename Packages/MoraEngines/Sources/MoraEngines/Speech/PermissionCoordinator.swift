import Foundation

public enum PermissionStatus: Equatable, Sendable {
    case notDetermined
    case allGranted
    case partial(micDenied: Bool, speechDenied: Bool)
}

@MainActor
public final class PermissionCoordinator {
    private let source: PermissionSource

    public init(source: PermissionSource) {
        self.source = source
    }

    #if os(iOS)
    public convenience init() {
        self.init(source: ApplePermissionSource())
    }
    #endif

    public func current() -> PermissionStatus {
        let mic = source.currentMic()
        let speech = source.currentSpeech()
        return map(mic: mic, speech: speech)
    }

    /// Sequentially request mic first, then speech. Returns the coordinator's
    /// collapsed status after both calls return.
    public func request() async -> PermissionStatus {
        let mic = await source.requestMic()
        let speech = await source.requestSpeech()
        return map(mic: mic, speech: speech)
    }

    private func map(mic: PermissionOutcome, speech: PermissionOutcome) -> PermissionStatus {
        // If either permission is still not-determined, the coordinator has
        // nothing definitive to say — the caller should prompt. Only collapse
        // to .partial once both have been decided.
        if mic == .notDetermined || speech == .notDetermined {
            return .notDetermined
        }
        if mic == .granted && speech == .granted {
            return .allGranted
        }
        return .partial(
            micDenied: mic == .denied,
            speechDenied: speech == .denied
        )
    }
}
