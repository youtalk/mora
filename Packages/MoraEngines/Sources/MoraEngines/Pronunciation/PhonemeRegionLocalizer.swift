import Foundation
import MoraCore

public enum PhonemePosition: Sendable, Hashable {
    case onset
    case coda
    case medial(position: Int, count: Int)
}

public struct LocalizedRegion: Sendable {
    public let clip: AudioClip
    public let startMs: Double
    public let durationMs: Double
    public let isReliable: Bool
}

public enum PhonemeRegionLocalizer {

    /// Slices an audio clip to the portion corresponding to a phoneme
    /// position within a word. The current heuristic is based only on clip
    /// timing and `phonemePosition`; `word` is reserved for future heuristics
    /// that use lexical/phoneme context. Onset and coda use a fixed 150 ms
    /// (or 25 % of the clip, whichever is smaller) window. Medial positions
    /// use the same equal-segment idea, dividing the clip into `count` equal
    /// units and selecting the `position`-th unit; this is accurate enough
    /// for short CVC words like `cat`/`cut` where the medial vowel sits in
    /// the middle third of the clip. A `position` outside `0..<count` is
    /// treated as malformed input and falls back to the full clip flagged
    /// unreliable.
    public static func region(
        clip: AudioClip,
        word _: Word,
        phonemePosition: PhonemePosition
    ) -> LocalizedRegion {
        let totalMs = clip.durationSeconds * 1000.0
        let fixedMs = 150.0
        let fractionMs = totalMs * 0.25
        let sliceMs = min(fixedMs, fractionMs)

        switch phonemePosition {
        case .onset:
            return slice(clip: clip, startMs: 0, durationMs: sliceMs, reliable: true)
        case .coda:
            return slice(clip: clip, startMs: totalMs - sliceMs, durationMs: sliceMs, reliable: true)
        case .medial(let position, let count):
            guard count > 0, position >= 0, position < count else {
                return LocalizedRegion(clip: clip, startMs: 0, durationMs: totalMs, isReliable: false)
            }
            let unit = totalMs / Double(count)
            let startMs = Double(position) * unit
            return slice(clip: clip, startMs: startMs, durationMs: unit, reliable: true)
        }
    }

    /// Derives a `PhonemePosition` from the word's phoneme array + target.
    public static func position(of target: Phoneme, in word: Word) -> PhonemePosition? {
        guard let idx = word.phonemes.firstIndex(of: target) else { return nil }
        if idx == 0 { return .onset }
        if idx == word.phonemes.count - 1 { return .coda }
        return .medial(position: idx, count: word.phonemes.count)
    }

    private static func slice(
        clip: AudioClip,
        startMs: Double,
        durationMs: Double,
        reliable: Bool
    ) -> LocalizedRegion {
        let startSample = max(0, Int(startMs / 1000.0 * clip.sampleRate))
        let endSample = min(clip.samples.count, startSample + Int(durationMs / 1000.0 * clip.sampleRate))
        guard endSample > startSample else {
            return LocalizedRegion(
                clip: AudioClip(samples: [], sampleRate: clip.sampleRate),
                startMs: startMs,
                durationMs: 0,
                isReliable: false
            )
        }
        let slice = Array(clip.samples[startSample..<endSample])
        return LocalizedRegion(
            clip: AudioClip(samples: slice, sampleRate: clip.sampleRate),
            startMs: startMs,
            durationMs: durationMs,
            isReliable: reliable
        )
    }
}
