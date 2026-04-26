import Foundation
import MoraCore

/// Speech tempo selected by the caller based on pedagogical context — not by
/// the engine. Phoneme drilling, new-rule intros, and corrective modeling use
/// `.slow` so the learner can map sound → letter; connected reading and
/// celebratory prompts use `.normal` so the session doesn't drag. `.verySlow`
/// is reserved for the dictation read-aloud prompt where the learner needs
/// to parse a multi-word sentence audibly enough to repeat it back; only
/// applied when an `.enhanced` / `.premium` voice is installed because the
/// compact-voice fallback degrades below `.slow`.
public enum TTSPace: Sendable {
    case verySlow
    case slow
    case normal
}

public protocol TTSEngine: Sendable {
    func speak(_ text: String, pace: TTSPace) async
    func speak(phoneme: Phoneme, pace: TTSPace) async
    /// Stops any utterance currently playing and drains queued utterances.
    /// Call on session dismissal so audio doesn't trail past the screen it
    /// belongs to.
    func stop() async
}

extension TTSEngine {
    public func speak(_ text: String) async {
        await speak(text, pace: .normal)
    }

    /// Phoneme isolation defaults to `.slow` because the learner is mapping
    /// sound → letter and needs the exemplar word enunciated, not rushed.
    public func speak(phoneme: Phoneme) async {
        await speak(phoneme: phoneme, pace: .slow)
    }
}
