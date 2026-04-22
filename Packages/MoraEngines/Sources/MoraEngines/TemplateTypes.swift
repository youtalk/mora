import Foundation
import MoraCore

public enum SlotKind: String, Hashable, Codable, Sendable, CaseIterable {
    case subject
    case verb
    case noun
    case adjective
}

public struct Template: Hashable, Codable, Sendable, Identifiable {
    public var id: String { skeleton }
    public let skeleton: String
    public let slotKinds: [String: SlotKind]

    public init(skeleton: String, slotKinds: [String: SlotKind]) {
        self.skeleton = skeleton
        self.slotKinds = slotKinds
    }

    public var slotNames: [String] {
        var out: [String] = []
        var i = skeleton.startIndex
        while let open = skeleton[i...].firstIndex(of: "{"),
              let close = skeleton[open...].firstIndex(of: "}") {
            let name = String(skeleton[skeleton.index(after: open)..<close])
            out.append(name)
            i = skeleton.index(after: close)
        }
        return out
    }
}

public struct VocabularyItem: Hashable, Codable, Sendable {
    public let word: Word
    public let slotKinds: Set<SlotKind>
    public let interest: InterestCategory?

    public init(word: Word, slotKinds: Set<SlotKind>,
                interest: InterestCategory? = nil) {
        self.word = word
        self.slotKinds = slotKinds
        self.interest = interest
    }
}
