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

        return violations
    }
}
