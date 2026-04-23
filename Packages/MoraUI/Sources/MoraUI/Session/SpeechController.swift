import Foundation
import MoraCore
import MoraEngines

/// A single utterance passed to `SpeechController.play`. Phoneme prompts
/// go through the engine's IPA pronunciation path; text prompts speak
/// the string verbatim. `pace` is chosen by the caller based on
/// pedagogical context — slow for phoneme drilling / corrective modeling,
/// normal for connected reading / celebratory prompts.
public enum SpeechPrompt: Sendable {
    case text(String, TTSPace)
    case phoneme(Phoneme, TTSPace)
}

/// Owns the session's TTS playback. Views describe what should be spoken
/// by calling `play([...])`; the controller cancels any earlier sequence
/// and starts the new one. Routing every utterance through a single owner
/// is what makes "stop the previous screen's audio before the next screen
/// appears" possible — direct `tts.speak` calls from views have no single
/// chokepoint to cancel, so a multi-step `.task { await tts.speak(a); await
/// tts.speak(b); ... }` keeps issuing prompts on the next screen even after
/// the view that started it has disappeared.
@MainActor
public final class SpeechController {
    private let tts: any TTSEngine
    private var inflight: Task<Void, Never>?

    public init(tts: any TTSEngine) {
        self.tts = tts
    }

    /// Cancels the in-flight sequence (if any) and speaks `prompts` in order.
    /// Returns a handle so callers inside `.task { ... }` can `await .value`
    /// to run follow-up work only after playback completes. Sequential
    /// iteration checks `Task.isCancelled` between prompts so a cancelled
    /// sequence stops immediately instead of queueing the remainder into
    /// the engine.
    @discardableResult
    public func play(_ prompts: [SpeechPrompt]) -> Task<Void, Never> {
        inflight?.cancel()
        let engine = tts
        let task = Task { @MainActor in
            for prompt in prompts {
                if Task.isCancelled { return }
                switch prompt {
                case .text(let text, let pace):
                    await engine.speak(text, pace: pace)
                case .phoneme(let phoneme, let pace):
                    await engine.speak(phoneme: phoneme, pace: pace)
                }
            }
        }
        inflight = task
        return task
    }

    /// Plays a sequence and awaits its completion, forwarding the caller's
    /// task cancellation into the playback task. Use inside `.task { ... }`
    /// when the view also needs to know when playback finished (for example
    /// to enable a "Got it" CTA only after the intro audio plays through).
    public func playAndAwait(_ prompts: [SpeechPrompt]) async {
        let task = play(prompts)
        await withTaskCancellationHandler {
            _ = await task.value
        } onCancel: {
            task.cancel()
        }
    }

    /// Cancels the in-flight sequence and drains the engine. Awaits the
    /// engine's `stop()` so callers (close button, dismiss) can sequence
    /// a navigation step after silence — if we returned before the engine
    /// finished draining, the last utterance's tail could still ride out
    /// onto the next screen.
    public func stop() async {
        inflight?.cancel()
        inflight = nil
        await tts.stop()
    }
}
