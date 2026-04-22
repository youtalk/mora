import Foundation

enum PromptLibrary {
    static let all: [BenchPrompt] = [
        slotFillShort(),
        slotFillWithHistory(),
        freeformDecodable(),
        vocabExpansion(),
    ]

    private static let frozen = loadFrozen()

    private static func loadFrozen() -> FrozenSnapshot {
        guard let url = Bundle.main.url(forResource: "templates-frozen", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(FrozenSnapshot.self, from: data) else {
            return FrozenSnapshot.empty
        }
        return decoded
    }

    private static func slotFillShort() -> BenchPrompt {
        let sys = """
            You fill JSON slot templates for a decodable reading tutor. Respond with \
            only a JSON object mapping slot names to single English words taken from the \
            provided vocabulary list. Use only taught graphemes plus the target grapheme. \
            Do not add keys or prose.
            """
        let user = """
            target_grapheme: \(frozen.targetGrapheme)
            taught_graphemes: \(frozen.taughtGraphemes.joined(separator: ","))
            template: "\(frozen.templates.first ?? "The {subject} {verb} a {noun}.")"
            vocabulary.subject: \(frozen.vocabulary["subject"]?.joined(separator: ",") ?? "")
            vocabulary.verb: \(frozen.vocabulary["verb"]?.joined(separator: ",") ?? "")
            vocabulary.noun: \(frozen.vocabulary["noun"]?.joined(separator: ",") ?? "")
            Return JSON now.
            """
        return BenchPrompt(
            id: "slot-fill-short",
            displayName: "Slot-fill (short)",
            systemPrompt: sys,
            userPrompt: user,
            expectedApproxOutputTokens: 30,
            shapeLabel: "~200 in / ~30 out"
        )
    }

    private static func slotFillWithHistory() -> BenchPrompt {
        let history = (1...5).map { i in
            "turn_\(i): \"\(frozen.templates.randomElement() ?? "The ship is big.")\" duration_ms=\(800 + i * 37)"
        }.joined(separator: "\n")
        let sys = slotFillShort().systemPrompt
        let user = """
            history:
            \(history)
            target_grapheme: \(frozen.targetGrapheme)
            taught_graphemes: \(frozen.taughtGraphemes.joined(separator: ","))
            template: "\(frozen.templates.last ?? "The {subject} has a {noun}.")"
            vocabulary.subject: \(frozen.vocabulary["subject"]?.joined(separator: ",") ?? "")
            vocabulary.verb: \(frozen.vocabulary["verb"]?.joined(separator: ",") ?? "")
            vocabulary.noun: \(frozen.vocabulary["noun"]?.joined(separator: ",") ?? "")
            vocabulary.adjective: \(frozen.vocabulary["adjective"]?.joined(separator: ",") ?? "")
            Avoid repeating words from history. Return JSON now.
            """
        return BenchPrompt(
            id: "slot-fill-history",
            displayName: "Slot-fill with history",
            systemPrompt: sys,
            userPrompt: user,
            expectedApproxOutputTokens: 40,
            shapeLabel: "~400 in / ~40 out"
        )
    }

    private static func freeformDecodable() -> BenchPrompt {
        let sys = """
            Write one short English sentence a 2nd grader can read. Use only the taught \
            graphemes plus the target grapheme. No quotation marks, no commentary.
            """
        let user = """
            target_grapheme: \(frozen.targetGrapheme)
            taught_graphemes: \(frozen.taughtGraphemes.joined(separator: ","))
            Write the sentence now.
            """
        return BenchPrompt(
            id: "freeform-decodable",
            displayName: "Freeform decodable sentence",
            systemPrompt: sys,
            userPrompt: user,
            expectedApproxOutputTokens: 150,
            shapeLabel: "~80 in / ~150 out"
        )
    }

    private static func vocabExpansion() -> BenchPrompt {
        let sys = """
            Suggest 3-5 additional English nouns related to the topic that can be read \
            using only the taught graphemes plus the target grapheme. Respond with only \
            a JSON array of strings.
            """
        let user = """
            topic: "Pokemon"
            target_grapheme: \(frozen.targetGrapheme)
            taught_graphemes: \(frozen.taughtGraphemes.joined(separator: ","))
            existing_nouns: \(frozen.vocabulary["noun"]?.joined(separator: ",") ?? "")
            Return JSON array now.
            """
        return BenchPrompt(
            id: "vocab-expansion",
            displayName: "Vocab expansion (v1.5)",
            systemPrompt: sys,
            userPrompt: user,
            expectedApproxOutputTokens: 50,
            shapeLabel: "~200 in / ~50 out"
        )
    }
}

private struct FrozenSnapshot: Decodable {
    let targetGrapheme: String
    let taughtGraphemes: [String]
    let vocabulary: [String: [String]]
    let templates: [String]

    static let empty = FrozenSnapshot(
        targetGrapheme: "sh",
        taughtGraphemes: [],
        vocabulary: [:],
        templates: []
    )

    enum CodingKeys: String, CodingKey {
        case targetGrapheme = "target_grapheme"
        case taughtGraphemes = "taught_graphemes"
        case vocabulary
        case templates
    }
}
