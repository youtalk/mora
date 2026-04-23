import Foundation

/// A finalized speech trial: the ASR transcript plus the raw audio clip the
/// transcript was produced from. The audio slice covers the recognized
/// utterance with a short trailing silence (typically 100 ms) so feature
/// extraction has enough room around word boundaries.
public struct TrialRecording: Sendable, Hashable, Codable {
    public let asr: ASRResult
    public let audio: AudioClip

    public init(asr: ASRResult, audio: AudioClip) {
        self.asr = asr
        self.audio = audio
    }
}
