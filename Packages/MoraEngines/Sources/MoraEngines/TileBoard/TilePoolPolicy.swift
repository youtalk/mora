import Foundation
import MoraCore

/// Describes how the engine should compose a tile pool for a trial.
public enum TilePoolPolicy: Hashable, Sendable {
    case buildFromWord(word: Word, extraDistractors: Int)
    case changeSlot(correct: Grapheme, kind: TileKind, extraDistractors: Int)
    case reducedToTwo(correct: Grapheme, distractor: Grapheme)

    /// Resolve the policy against a pool of candidate distractor graphemes.
    /// Duplicates and the correct tile(s) are filtered out of the distractors
    /// so `resolve` never returns a pool with duplicate grapheme ids.
    public func resolve(distractorsPool: Set<Grapheme>) -> [Tile] {
        switch self {
        case let .buildFromWord(word, extra):
            let required = Set(word.graphemes)
            let pool = distractorsPool.subtracting(required)
            let chosen = Array(pool.sorted { $0.letters < $1.letters }.prefix(extra))
            return (Array(required) + chosen).map(Tile.init)
        case let .changeSlot(correct, kind, extra):
            var candidates = distractorsPool
                .filter { TileKind(grapheme: $0) == kind && $0 != correct }
                .sorted { $0.letters < $1.letters }
            candidates = Array(candidates.prefix(extra))
            return ([correct] + candidates).map(Tile.init)
        case let .reducedToTwo(correct, distractor):
            return [correct, distractor].map(Tile.init)
        }
    }
}
