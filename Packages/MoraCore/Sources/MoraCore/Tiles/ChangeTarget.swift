import Foundation

/// A successor in a word chain: exactly one slot differs from the
/// predecessor. `init` returns `nil` when that invariant does not hold.
public struct ChangeTarget: Hashable, Codable, Sendable {
    public let predecessor: Word
    public let successor: Word
    public let changedIndex: Int

    public init?(predecessor: Word, successor: Word) {
        let pre = predecessor.graphemes
        let suc = successor.graphemes
        guard pre.count == suc.count else { return nil }
        var diffs: [Int] = []
        for index in pre.indices where pre[index] != suc[index] {
            diffs.append(index)
            if diffs.count > 1 { return nil }
        }
        guard let only = diffs.first else { return nil }
        self.predecessor = predecessor
        self.successor = successor
        self.changedIndex = only
    }

    public var oldGrapheme: Grapheme { predecessor.graphemes[changedIndex] }
    public var newGrapheme: Grapheme { successor.graphemes[changedIndex] }
}
