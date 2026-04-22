import AVFoundation
import Foundation
import MoraCore
import OSLog

private let audioLog = Logger(subsystem: "tech.reenable.Mora", category: "AudioSession")

public actor AppleTTSEngine: TTSEngine {
    private let synthesizer: AVSpeechSynthesizer
    private let delegateProxy: DelegateProxy
    private let l1Profile: any L1Profile
    private let rate: Float
    public let preferredVoiceIdentifier: String?

    public init(
        l1Profile: any L1Profile,
        preferredVoiceIdentifier: String? = nil,
        rate: Float = 0.45
    ) {
        self.l1Profile = l1Profile
        self.preferredVoiceIdentifier = preferredVoiceIdentifier
        self.rate = rate
        let synth = AVSpeechSynthesizer()
        let proxy = DelegateProxy()
        synth.delegate = proxy
        self.synthesizer = synth
        self.delegateProxy = proxy
    }

    public func speak(_ text: String) async {
        await speak(text: text)
    }

    public func speak(phoneme: Phoneme) async {
        let exemplars = l1Profile.exemplars(for: phoneme)
        let lead: String
        switch phoneme.ipa {
        case "ʃ": lead = "sh"
        case "tʃ": lead = "ch"
        case "θ": lead = "th"
        default: lead = phoneme.ipa
        }
        let text: String
        if let first = exemplars.first {
            text = "\(lead), as in \(first)."
        } else {
            text = "the \(lead) sound."
        }
        await speak(text: text)
    }

    /// `true` when no installed en-US voice is enhanced or premium. Callers
    /// (HomeView) surface a prompt linking into Settings when this is true.
    /// Static because it reads process-wide voice metadata; keeps the
    /// HomeView chip and TTS engine reading from one source.
    public nonisolated static var needsEnhancedVoice: Bool {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en-US") }
        return !voices.contains { $0.quality == .enhanced || $0.quality == .premium }
    }

    private func speak(text: String) async {
        configurePlaybackSession()
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.voice = pickVoice()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            delegateProxy.enqueue { cont.resume() }
            synthesizer.speak(utterance)
        }
    }

    /// AppleSpeechEngine leaves the audio session in `.record` category and
    /// never deactivates it, so a TTS call running right after a decode phase
    /// would otherwise route through the receiver and be inaudible on iPad.
    /// Re-categorize to `.playback` per utterance; the speech engine flips it
    /// back on its next `listen()`. Failures are logged (so a session misconfig
    /// is visible in device sysdiagnose) but don't suppress the speak attempt.
    private func configurePlaybackSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
            try session.setActive(true, options: [])
        } catch {
            audioLog.error("AppleTTSEngine: failed to configure playback session: \(error)")
        }
        #endif
    }

    private func pickVoice() -> AVSpeechSynthesisVoice? {
        if let id = preferredVoiceIdentifier,
            let v = AVSpeechSynthesisVoice(identifier: id)
        {
            return v
        }
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en-US") }
        if let premium = voices.first(where: { $0.quality == .premium }) { return premium }
        if let enhanced = voices.first(where: { $0.quality == .enhanced }) { return enhanced }
        return voices.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}

/// AVSpeechSynthesizerDelegate requires an NSObject; this proxy forwards
/// `didFinish` / `didCancel` into a FIFO queue of continuation handlers so
/// overlapping `speak(_:)` calls each get their own completion. A single-slot
/// handler would race under actor re-entrance (speak A awaits → speak B
/// overwrites A's handler → only B's continuation resumes, A hangs).
private final class DelegateProxy: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var handlers: [() -> Void] = []

    func enqueue(_ handler: @escaping () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        handlers.append(handler)
    }

    private func takeNext() -> (() -> Void)? {
        lock.lock()
        defer { lock.unlock() }
        return handlers.isEmpty ? nil : handlers.removeFirst()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        takeNext()?()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        takeNext()?()
    }
}
