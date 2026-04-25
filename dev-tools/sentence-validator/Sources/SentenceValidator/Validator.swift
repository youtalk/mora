import Foundation
import MoraCore
import MoraEngines

/// One reason a sentence failed validation. Future tasks add more cases;
/// keep `Equatable` synthesis clean by using only stored-value associated
/// data (no closures, no functions).
enum Violation: Equatable {
    case undecodableGrapheme(word: String, grapheme: String)
    case targetCountTooLow(actual: Int, minimum: Int)
    case targetInitialContentWordsTooLow(actual: Int, minimum: Int)
    case interestWordsEmpty
    case interestWordNotInSentence(interestWord: String)
    case lengthOutOfRange(actual: Int, minimum: Int, maximum: Int)
}

enum Validator {
    /// Validate a single sentence against its cell's rules.
    /// `map` selects the phoneme-specific allowed grapheme set; `curriculum`
    /// resolves the taught set; `sightWords` is the global whitelist.
    static func validate(
        sentence: CellSentencePayload,
        map: PhonemeDirectoryMap,
        curriculum: CurriculumEngine,
        sightWords: Set<String>,
    ) -> [Violation] {
        var violations: [Violation] = []

        let allowed: Set<Grapheme> =
            curriculum.taughtGraphemes(beforeWeekIndex: map.weekIndex)
                .union([map.target])

        for word in sentence.words {
            if sightWords.contains(word.surface.lowercased()) { continue }
            for letters in word.graphemes {
                let g = Grapheme(letters: letters)
                if allowed.contains(g) { continue }
                violations.append(.undecodableGrapheme(word: word.surface, grapheme: letters))
            }
        }

        let targetLetters = map.target.letters
        let totalTargetCount = sentence.words.reduce(0) { acc, word in
            acc + word.graphemes.filter { $0 == targetLetters }.count
        }
        if totalTargetCount < 4 {
            violations.append(.targetCountTooLow(actual: totalTargetCount, minimum: 4))
        }

        let initialInContent = sentence.words.reduce(0) { acc, word in
            // "Content word" = anything not in the sight-word whitelist. Proper
            // nouns, regular nouns, verbs, adjectives all count; only the seven
            // sight words are excluded.
            guard !sightWords.contains(word.surface.lowercased()) else { return acc }
            guard let first = word.graphemes.first, first == targetLetters else { return acc }
            return acc + 1
        }
        if initialInContent < 3 {
            violations.append(.targetInitialContentWordsTooLow(actual: initialInContent, minimum: 3))
        }

        if sentence.interestWords.isEmpty {
            violations.append(.interestWordsEmpty)
        } else {
            // Loose check: each interestWords entry must appear in the
            // sentence's word surfaces (case-insensitive). Rejects authoring
            // typos like "vans" tagged when only "van" appears.
            let surfaces = Set(sentence.words.map { $0.surface.lowercased() })
            for tag in sentence.interestWords {
                if !surfaces.contains(tag.lowercased()) {
                    violations.append(.interestWordNotInSentence(interestWord: tag))
                }
            }
        }

        let length = sentence.words.count
        if length < 6 || length > 10 {
            violations.append(.lengthOutOfRange(actual: length, minimum: 6, maximum: 10))
        }

        return violations
    }
}
