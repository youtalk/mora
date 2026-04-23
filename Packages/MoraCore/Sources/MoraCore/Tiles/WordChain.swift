import Foundation

/// One four-word mini-chain. Head is a Build; each successor is a Change
/// that differs from its predecessor by exactly one grapheme at one index.
/// All words must be decodable within `inventory`.
public struct WordChain: Hashable, Codable, Sendable {
    public let role: ChainRole
    public let head: BuildTarget
    public let successors: [ChangeTarget]

    public init?(
        role: ChainRole,
        head: BuildTarget,
        successorWords: [Word],
        inventory: Set<Grapheme>
    ) {
        guard Self.isDecodable(head.word, inventory: inventory) else { return nil }
        var built: [ChangeTarget] = []
        var previous = head.word
        for next in successorWords {
            guard Self.isDecodable(next, inventory: inventory) else { return nil }
            guard let change = ChangeTarget(predecessor: previous, successor: next) else { return nil }
            built.append(change)
            previous = next
        }
        self.role = role
        self.head = head
        self.successors = built
    }

    public var allWords: [Word] {
        [head.word] + successors.map(\.successor)
    }

    private static func isDecodable(_ word: Word, inventory: Set<Grapheme>) -> Bool {
        word.graphemes.allSatisfy { inventory.contains($0) }
    }
}
