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
    // Resolving the voice walks `AVSpeechSynthesisVoice.speechVoices()` (~50-100
    // entries). The installed voice set is stable for the process lifetime, so
    // cache the first lookup and reuse it for every subsequent utterance.
    private var cachedVoice: AVSpeechSynthesisVoice?
    private var voiceResolved = false

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
        await speak(text: Self.phoneticLeadPhrase(for: phoneme, using: l1Profile))
    }

    /// Builds the "sh, as in ship." lead phrase spoken by `speak(phoneme:)`.
    /// Extracted as a pure function so it can be unit-tested without audio
    /// (tests reach it via `@testable import MoraEngines`); kept internal so
    /// this helper isn't part of the module's published API surface.
    nonisolated static func phoneticLeadPhrase(
        for phoneme: Phoneme, using profile: any L1Profile
    ) -> String {
        let lead: String
        switch phoneme.ipa {
        case "ʃ": lead = "sh"
        case "tʃ": lead = "ch"
        case "θ": lead = "th"
        default: lead = phoneme.ipa
        }
        if let first = profile.exemplars(for: phoneme).first {
            return "\(lead), as in \(first)."
        }
        return "the \(lead) sound."
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
        // Bail before the synthesizer ever sees the utterance if our caller
        // is already cancelled. Without this, a view whose driving `Task`
        // was cancelled (view disappeared) would still issue every remaining
        // prompt in its `for word in ... { await speak }` loop — the prior
        // screen's audio would then play on the next screen because nothing
        // in the actor method checks cancellation.
        if Task.isCancelled { return }
        configurePlaybackSession()
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.voice = pickVoice()
        // `withTaskCancellationHandler` fires `onCancel` when the enclosing
        // Swift task is cancelled, including cancel events that arrive
        // while we're suspended inside `withCheckedContinuation`. The
        // handler hops back onto the actor to stop the synthesizer, which
        // triggers `didCancel` on the delegate proxy and resumes the
        // awaiting continuation — so an aborted speak returns immediately
        // rather than dragging on through the utterance's full duration.
        await withTaskCancellationHandler {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                delegateProxy.enqueue { cont.resume() }
                synthesizer.speak(utterance)
            }
        } onCancel: { [weak self] in
            Task { await self?.cancelCurrentUtterance() }
        }
    }

    /// Invoked from `onCancel` handlers on a non-actor executor; the `Task`
    /// wrapper above hops us back onto the actor so the AVSpeechSynthesizer
    /// call is serialized with the rest of our engine state.
    private func cancelCurrentUtterance() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
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
        if voiceResolved { return cachedVoice }
        cachedVoice = resolveVoice()
        voiceResolved = true
        return cachedVoice
    }

    private func resolveVoice() -> AVSpeechSynthesisVoice? {
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
