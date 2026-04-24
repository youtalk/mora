import Foundation

public enum FixtureCatalog {

    /// The canonical 12-pattern list the recorder UI walks.
    /// Source of truth: followup plan 2026-04-23-pronunciation-bench-followups.md
    /// Task A1 Step 2. phonemeSequenceIPA / targetPhonemeIndex are
    /// pre-baked so medial vowels localize correctly in downstream
    /// PhonemeRegionLocalizer without user input.
    public static let v1Patterns: [FixturePattern] = [
        // r / l — onset consonant, target index 0
        FixturePattern(
            id: "rl-right-correct",
            targetPhonemeIPA: "r",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "right",
            phonemeSequenceIPA: ["r", "aɪ", "t"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "rl",
            filenameStem: "right-correct"
        ),
        FixturePattern(
            id: "rl-right-as-light",
            targetPhonemeIPA: "r",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "l",
            wordSurface: "right",
            phonemeSequenceIPA: ["r", "aɪ", "t"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "rl",
            filenameStem: "right-as-light"
        ),
        FixturePattern(
            id: "rl-light-correct",
            targetPhonemeIPA: "l",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "light",
            phonemeSequenceIPA: ["l", "aɪ", "t"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "rl",
            filenameStem: "light-correct"
        ),
        FixturePattern(
            id: "rl-light-as-right",
            targetPhonemeIPA: "l",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "r",
            wordSurface: "light",
            phonemeSequenceIPA: ["l", "aɪ", "t"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "rl",
            filenameStem: "light-as-right"
        ),

        // v / b — onset consonant, target index 0
        FixturePattern(
            id: "vb-very-correct",
            targetPhonemeIPA: "v",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "very",
            phonemeSequenceIPA: ["v", "ɛ", "r", "i"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "vb",
            filenameStem: "very-correct"
        ),
        FixturePattern(
            id: "vb-very-as-berry",
            targetPhonemeIPA: "v",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "b",
            wordSurface: "very",
            phonemeSequenceIPA: ["v", "ɛ", "r", "i"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "vb",
            filenameStem: "very-as-berry"
        ),
        FixturePattern(
            id: "vb-berry-correct",
            targetPhonemeIPA: "b",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "berry",
            phonemeSequenceIPA: ["b", "ɛ", "r", "i"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "vb",
            filenameStem: "berry-correct"
        ),
        FixturePattern(
            id: "vb-berry-as-very",
            targetPhonemeIPA: "b",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "v",
            wordSurface: "berry",
            phonemeSequenceIPA: ["b", "ɛ", "r", "i"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "vb",
            filenameStem: "berry-as-very"
        ),

        // æ / ʌ — medial vowel, target index 1
        FixturePattern(
            id: "aeuh-cat-correct",
            targetPhonemeIPA: "æ",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "cat",
            phonemeSequenceIPA: ["k", "æ", "t"],
            targetPhonemeIndex: 1,
            outputSubdirectory: "aeuh",
            filenameStem: "cat-correct"
        ),
        FixturePattern(
            id: "aeuh-cat-as-cut",
            targetPhonemeIPA: "æ",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "ʌ",
            wordSurface: "cat",
            phonemeSequenceIPA: ["k", "æ", "t"],
            targetPhonemeIndex: 1,
            outputSubdirectory: "aeuh",
            filenameStem: "cat-as-cut"
        ),
        FixturePattern(
            id: "aeuh-cut-correct",
            targetPhonemeIPA: "ʌ",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "cut",
            phonemeSequenceIPA: ["k", "ʌ", "t"],
            targetPhonemeIndex: 1,
            outputSubdirectory: "aeuh",
            filenameStem: "cut-correct"
        ),
        FixturePattern(
            id: "aeuh-cut-as-cat",
            targetPhonemeIPA: "ʌ",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "æ",
            wordSurface: "cut",
            phonemeSequenceIPA: ["k", "ʌ", "t"],
            targetPhonemeIndex: 1,
            outputSubdirectory: "aeuh",
            filenameStem: "cut-as-cat"
        ),
    ]
}
