import Foundation
import MoraCore

/// One trial's inputs: either a fresh Build head or a Change on top of
/// already-placed tiles.
public enum TileBoardTrial: Hashable, Sendable {
    case build(target: BuildTarget, pool: [Tile])
    case change(target: ChangeTarget, lockedSlots: [Grapheme], pool: [Tile])

    public var expectedSlots: [Grapheme] {
        switch self {
        case let .build(target, _): return target.slots
        case let .change(target, _, _): return target.successor.graphemes
        }
    }

    public var activeSlotIndex: Int? {
        switch self {
        case .build: return nil
        case let .change(target, _, _): return target.changedIndex
        }
    }

    public var pool: [Tile] {
        switch self {
        case let .build(_, pool): return pool
        case let .change(_, _, pool): return pool
        }
    }

    public var word: Word {
        switch self {
        case let .build(target, _): return target.word
        case let .change(target, _, _): return target.successor
        }
    }
}
