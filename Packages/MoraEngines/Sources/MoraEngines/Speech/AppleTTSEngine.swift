import AVFoundation
import Foundation
import MoraCore

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
    /// Nonisolated because it reads process-wide voice metadata; no actor
    /// state is touched.
    public nonisolated var needsEnhancedVoice: Bool {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en-US") }
        return !voices.contains { $0.quality == .enhanced || $0.quality == .premium }
    }

    private func speak(text: String) async {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.voice = pickVoice()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            delegateProxy.setOnFinish { cont.resume() }
            synthesizer.speak(utterance)
        }
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
/// `didFinish` / `didCancel` into a single-shot continuation so callers can
/// `await` `speak(_:)`. A fresh continuation is installed per utterance.
private final class DelegateProxy: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var onFinish: (() -> Void)?

    func setOnFinish(_ handler: @escaping () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        onFinish = handler
    }

    private func takeHandler() -> (() -> Void)? {
        lock.lock()
        defer { lock.unlock() }
        let h = onFinish
        onFinish = nil
        return h
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        takeHandler()?()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        takeHandler()?()
    }
}
