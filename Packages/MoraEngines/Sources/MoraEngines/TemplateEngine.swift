import Foundation
import MoraCore

public struct SeededRNG: Sendable {
    private var state: UInt64

    public init(seed: UInt64) { self.state = seed == 0 ? 0xdeadbeef : seed }

    public mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Int(state % UInt64(upperBound))
    }
}

public struct TemplateEngine: Sendable {
    public let templates: [Template]
    public let vocabulary: [VocabularyItem]

    public init(templates: [Template], vocabulary: [VocabularyItem]) {
        self.templates = templates
        self.vocabulary = vocabulary
    }

    public func generateSentence(
        target: Grapheme,
        taughtGraphemes: Set<Grapheme>,
        interests: [InterestCategory],
        rng: inout SeededRNG,
        maxAttempts: Int = 50
    ) -> DecodeSentence? {
        guard !templates.isEmpty else { return nil }
        let interestKeys = Set(interests.map(\.key))

        for _ in 0..<maxAttempts {
            let template = templates[rng.nextInt(upperBound: templates.count)]
            if let filled = (try? fill(
                template: template,
                target: target,
                taughtGraphemes: taughtGraphemes,
                interestKeys: interestKeys,
                rng: &rng
            )) ?? nil {
                return filled
            }
        }
        return nil
    }

    private func fill(
        template: Template,
        target: Grapheme,
        taughtGraphemes: Set<Grapheme>,
        interestKeys: Set<String>,
        rng: inout SeededRNG
    ) throws -> DecodeSentence? {
        var text = template.skeleton
        var usedWords: [Word] = []

        for slotName in template.slotNames {
            guard let kind = template.slotKinds[slotName] else {
                throw TemplateEngineError.slotKindMissing(slotName)
            }
            let candidates = vocabulary.filter { item in
                guard item.slotKinds.contains(kind) else { return false }
                if !interestKeys.isEmpty, let i = item.interest,
                   !interestKeys.contains(i.key) { return false }
                return item.word.isDecodable(
                    taughtGraphemes: taughtGraphemes,
                    target: target
                )
            }
            guard !candidates.isEmpty else { return nil }
            let pick = candidates[rng.nextInt(upperBound: candidates.count)]
            text = text.replacingOccurrences(of: "{\(slotName)}",
                                             with: pick.word.surface)
            usedWords.append(pick.word)
        }
        return DecodeSentence(text: text, words: usedWords)
    }
}

public enum TemplateEngineError: Error, Equatable {
    case slotKindMissing(String)
}
