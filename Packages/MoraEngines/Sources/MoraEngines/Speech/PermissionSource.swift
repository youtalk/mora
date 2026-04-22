import AVFoundation
import Foundation
import Speech

public enum PermissionOutcome: Equatable, Sendable {
    case notDetermined
    case granted
    case denied
}

/// Thin protocol wrapping the OS permission APIs so tests can inject fakes.
/// `ApplePermissionSource` is used in the app; `FakePermissionSource` lives
/// in MoraTesting.
@MainActor
public protocol PermissionSource: AnyObject {
    func currentMic() -> PermissionOutcome
    func currentSpeech() -> PermissionOutcome
    func requestMic() async -> PermissionOutcome
    func requestSpeech() async -> PermissionOutcome
}

#if os(iOS)
/// Production source backed by AVAudioApplication + SFSpeechRecognizer.
@MainActor
public final class ApplePermissionSource: PermissionSource {
    public init() {}

    public func currentMic() -> PermissionOutcome {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return .granted
        case .denied: return .denied
        case .undetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    public func currentSpeech() -> PermissionOutcome {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    public func requestMic() async -> PermissionOutcome {
        await withCheckedContinuation {
            (cont: CheckedContinuation<PermissionOutcome, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted ? .granted : .denied)
            }
        }
    }

    public func requestSpeech() async -> PermissionOutcome {
        await withCheckedContinuation {
            (cont: CheckedContinuation<PermissionOutcome, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized: cont.resume(returning: .granted)
                case .denied, .restricted: cont.resume(returning: .denied)
                case .notDetermined: cont.resume(returning: .notDetermined)
                @unknown default: cont.resume(returning: .denied)
                }
            }
        }
    }
}
#endif
