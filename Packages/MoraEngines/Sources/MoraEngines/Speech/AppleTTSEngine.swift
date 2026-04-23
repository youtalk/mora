import AVFoundation
import Foundation
import MoraCore
import OSLog

private let audioLog = Logger(subsystem: "tech.reenable.Mora", category: "AudioSession")

public actor AppleTTSEngine: TTSEngine {
    private let synthesizer: AVSpeechSynthesizer
    private let delegateProxy: DelegateProxy
    private let l1Profile: any L1Profile
    private let slowRate: Float
    private let normalRate: Float
    public let preferredVoiceIdentifier: String?
    // Resolving the voice walks `AVSpeechSynthesisVoice.speechVoices()` (~50-100
    // entries). The installed voice set is stable for the process lifetime, so
    // cache the first lookup and reuse it for every subsequent utterance.
    private var cachedVoice: AVSpeechSynthesisVoice?
    private var voiceResolved = false

    /// Rates are tuned for an ~8yo ESL learner with dyslexia: below the adult
    /// `AVSpeechUtteranceDefaultSpeechRate` (0.5) so sibilants and short words
    /// are audibly separable. These only apply when a `.enhanced` or `.premium`
    /// voice is installed — compact voices (`quality == .default`) use the
    /// system default rate because their formant synthesizer falls apart
    /// below 0.5 (children heard "ship" as garbled, unintelligible noise
    /// on device).
    public init(
        l1Profile: any L1Profile,
        preferredVoiceIdentifier: String? = nil,
        slowRate: Float = 0.40,
        normalRate: Float = 0.46
    ) {
        self.l1Profile = l1Profile
        self.preferredVoiceIdentifier = preferredVoiceIdentifier
        self.slowRate = slowRate
        self.normalRate = normalRate
        let synth = AVSpeechSynthesizer()
        let proxy = DelegateProxy()
        synth.delegate = proxy
        self.synthesizer = synth
        self.delegateProxy = proxy
    }

    public func speak(_ text: String, pace: TTSPace) async {
        await speakInternal(text: text, pace: pace, ipaOverride: nil)
    }

    public func speak(phoneme: Phoneme, pace: TTSPace) async {
        // Drive the synthesizer with an IPA pronunciation hint instead of
        // building an exemplar phrase ("sh, as in ship."). The IPA hint makes
        // Premium / Enhanced unit-selection and neural voices produce the
        // bare phoneme directly, which is what the warmup quiz actually
        // tests — and it sidesteps two failure modes:
        //   • Bare digraphs in plain text were spell-read ("sh" → "S, H").
        //   • Showing an exemplar caption alongside the audio leaked the
        //     answer to the learner (the grapheme sits inside the word).
        // The visible text passed to the synthesizer is the IPA glyph too,
        // so screen readers / accessibility users hear the same intent.
        await speakInternal(
            text: phoneme.ipa, pace: pace, ipaOverride: phoneme.ipa
        )
    }

    public func stop() async {
        // `stopSpeaking(.immediate)` cancels the current utterance and drains
        // any still-queued ones, each triggering `didCancel` which resumes the
        // corresponding awaiting `speak` caller via `DelegateProxy`. Guard on
        // `isSpeaking` so a no-op stop doesn't trip CoreAudio's
        // "AVAudioBuffer.mm: mBuffers[0].mDataByteSize (0) should be non-zero"
        // log every time a view appears with no prior audio in flight.
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// `true` when no installed English voice is enhanced or premium. Callers
    /// (HomeView) surface a prompt linking into Settings when this is true.
    /// Static because it reads process-wide voice metadata; keeps the
    /// HomeView chip and TTS engine reading from one source. Scans the same
    /// `en*` set `resolveVoice` considers so the gate matches actual playback
    /// capability — a device with only an Enhanced/Premium en-GB voice
    /// installed is fine, because `resolveVoice` will pick it.
    ///
    /// On macOS (native, Mac Catalyst, or "Designed for iPad" running on
    /// Apple Silicon Mac) we always return `false`: the standard Mac install
    /// ships only compact voices, so leaving the gate enabled traps the
    /// learner on the home screen forever. The ProcessInfo flags catch the
    /// runtime-on-Mac cases that are invisible to `#if os(macOS)` —
    /// `isiOSAppOnMac` is true for "Designed for iPad" on Apple Silicon Mac
    /// and `isMacCatalystApp` is true for Mac Catalyst, both of which
    /// compile as iOS binaries.
    public nonisolated static var needsEnhancedVoice: Bool {
        #if os(macOS)
        return false
        #else
        let info = ProcessInfo.processInfo
        if info.isiOSAppOnMac || info.isMacCatalystApp { return false }
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
        return !voices.contains { $0.quality == .enhanced || $0.quality == .premium }
        #endif
    }

    /// One-line summary per installed English voice — `"Ava · en-US · Premium"`
    /// style — sorted by quality descending. Used by the voice-gate card so the
    /// parent can see exactly what Mora sees on this device and tell whether
    /// the Settings download actually landed.
    public nonisolated static func installedEnglishVoiceSummaries() -> [String] {
        let english = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
        let sorted = english.sorted { lhs, rhs in
            if lhs.quality.rawValue != rhs.quality.rawValue {
                return lhs.quality.rawValue > rhs.quality.rawValue
            }
            if lhs.language != rhs.language {
                return lhs.language < rhs.language
            }
            return lhs.name < rhs.name
        }
        return sorted.map { voice in
            "\(voice.name) · \(voice.language) · \(qualityLabel(voice.quality))"
        }
    }

    private nonisolated static func qualityLabel(
        _ q: AVSpeechSynthesisVoiceQuality
    ) -> String {
        switch q {
        case .premium: return "Premium"
        case .enhanced: return "Enhanced"
        case .default: return "Default (compact)"
        @unknown default: return "Unknown"
        }
    }

    private func speakInternal(
        text: String, pace: TTSPace, ipaOverride: String?
    ) async {
        // Bail before the synthesizer ever sees the utterance if our caller
        // is already cancelled. Without this, a view whose driving `Task`
        // was cancelled (view disappeared) would still issue every remaining
        // prompt in its `for word in ... { await speak }` loop — the prior
        // screen's audio would then play on the next screen because nothing
        // in the actor method checks cancellation.
        if Task.isCancelled { return }
        configurePlaybackSession()
        // Preempt anything still playing or queued from a prior caller —
        // without this, a view transition leaves the outgoing screen's
        // utterance in the synthesizer queue and the incoming `speak` lines
        // up behind it. Guard on `isSpeaking`: a no-op stopSpeaking call
        // emits "AVAudioBuffer.mm: mDataByteSize (0)" every time and floods
        // Console during normal sequential playback within one view.
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let voice = pickVoice()
        // If we couldn't resolve any English voice, stay silent rather than
        // letting AVSpeechSynthesizer fall back to the system default voice —
        // on a Japanese iPad that default is a Japanese voice, which reads
        // "ship" through Japanese phonology and confuses the learner further.
        guard let voice, voice.language.hasPrefix("en") else {
            audioLog.error("AppleTTSEngine: no English voice available; skipping utterance")
            return
        }
        let utterance = utterance(text: text, ipa: ipaOverride)
        utterance.rate = rateFor(pace, voice: voice)
        utterance.voice = voice
        // `withTaskCancellationHandler` fires `onCancel` when the enclosing
        // Swift task is cancelled, including cancel events that arrive
        // while we're suspended inside `withCheckedContinuation`. The
        // handler hops back onto the actor to stop the synthesizer, which
        // triggers `didCancel` on the delegate proxy and resumes the
        // awaiting continuation — so an aborted speak returns immediately
        // rather than dragging on through the utterance's full duration.
        await withTaskCancellationHandler {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                // Re-check cancellation immediately before queuing the
                // utterance. Closes the tiny race where `onCancel` fires
                // between the outer `Task.isCancelled` check and this
                // point — without this, a cancelled caller could still
                // push an utterance into AVSpeechSynthesizer and we'd
                // rely on the `onCancel` hop to stop it (audible blip).
                if Task.isCancelled {
                    cont.resume()
                    return
                }
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

    /// Builds an `AVSpeechUtterance`. When `ipa` is non-nil the entire text
    /// range is annotated with `AVSpeechSynthesisIPANotationAttribute`, which
    /// instructs unit-selection / neural voices to pronounce the run using
    /// the supplied IPA notation. This is the only documented way to coax
    /// AVSpeechSynthesizer into producing a bare phoneme like /ʃ/ — passing
    /// "sh" as plain text degrades to a spell-out on every voice we tested.
    private func utterance(text: String, ipa: String?) -> AVSpeechUtterance {
        guard let ipa else { return AVSpeechUtterance(string: text) }
        let attr = NSMutableAttributedString(string: text)
        attr.addAttribute(
            NSAttributedString.Key(rawValue: AVSpeechSynthesisIPANotationAttribute),
            value: ipa,
            range: NSRange(location: 0, length: attr.length)
        )
        return AVSpeechUtterance(attributedString: attr)
    }

    private func rateFor(_ pace: TTSPace, voice: AVSpeechSynthesisVoice) -> Float {
        // Compact (`.default`) voices are formant-synthesized and fall apart
        // below the system default 0.5 — sibilants smear into noise, short
        // words lose their plosive boundaries. Only slow down when we have
        // a higher-quality unit-selection or neural voice.
        let isHighQuality = voice.quality == .enhanced || voice.quality == .premium
        guard isHighQuality else { return AVSpeechUtteranceDefaultSpeechRate }
        switch pace {
        case .slow: return slowRate
        case .normal: return normalRate
        }
    }

    /// AppleSpeechEngine leaves the audio session in `.record` category and
    /// never deactivates it, so a TTS call running right after a decode phase
    /// would otherwise route through the receiver and be inaudible on iPad.
    /// Re-categorize to `.playback` only when the current category isn't
    /// already that — repeated `setCategory` / `setActive` calls trip
    /// CoreAudio's empty-buffer log on every utterance. The speech engine
    /// flips the category back on its next `listen()`, so the next TTS call
    /// after recording correctly re-applies playback.
    private func configurePlaybackSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        if session.category == .playback,
            session.mode == .spokenAudio
        {
            return
        }
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
        if let v = cachedVoice {
            audioLog.debug(
                "AppleTTSEngine: picked voice id=\(v.identifier) lang=\(v.language) quality=\(v.quality.rawValue)"
            )
        } else {
            audioLog.error("AppleTTSEngine: no voice resolved")
        }
        return cachedVoice
    }

    private func resolveVoice() -> AVSpeechSynthesisVoice? {
        if let id = preferredVoiceIdentifier,
            let v = AVSpeechSynthesisVoice(identifier: id)
        {
            return v
        }
        // Widen the net beyond en-US: en-GB / en-AU / en-IE voices render
        // English text intelligibly, whereas the system-default Japanese voice
        // (on a JP-locale iPad with no English voices installed) does not.
        let english = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
        if let v = english.first(where: { $0.quality == .premium && $0.language == "en-US" }) {
            return v
        }
        if let v = english.first(where: { $0.quality == .enhanced && $0.language == "en-US" }) {
            return v
        }
        if let v = english.first(where: { $0.quality == .premium }) { return v }
        if let v = english.first(where: { $0.quality == .enhanced }) { return v }
        if let v = english.first(where: { $0.language == "en-US" }) { return v }
        if let v = english.first { return v }
        return AVSpeechSynthesisVoice(language: "en-US")
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
