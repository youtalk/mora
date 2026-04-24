import Foundation
import MoraCore

public struct ScriptedContentProvider: ContentProvider {
    public let target: Grapheme
    public let taughtGraphemes: Set<Grapheme>
    public let words: [DecodeWord]
    public let sentences: [DecodeSentence]

    public init(
        target: Grapheme,
        taughtGraphemes: Set<Grapheme>,
        words: [DecodeWord],
        sentences: [DecodeSentence]
    ) {
        self.target = target
        self.taughtGraphemes = taughtGraphemes
        self.words = words
        self.sentences = sentences
    }

    public func decodeWords(_ request: ContentRequest) throws -> [DecodeWord] {
        let filtered = words.filter { dw in
            dw.word.isDecodable(
                taughtGraphemes: request.taughtGraphemes,
                target: request.target) && dw.word.graphemes.contains(request.target)
        }
        return Array(filtered.prefix(request.count))
    }

    public func decodeSentences(_ request: ContentRequest) throws -> [DecodeSentence] {
        let filtered = sentences.filter { s in
            s.words.allSatisfy {
                $0.isDecodable(
                    taughtGraphemes: request.taughtGraphemes,
                    target: request.target)
            } && s.words.contains { $0.graphemes.contains(request.target) }
        }
        return Array(filtered.prefix(request.count))
    }

    // MARK: - Bundled "sh" week 1 preset

    public static func bundledShWeek1() throws -> ScriptedContentProvider {
        guard let url = Bundle.module.url(forResource: "sh_week1", withExtension: "json") else {
            throw ScriptedContentError.resourceMissing("sh_week1.json")
        }
        let data = try Data(contentsOf: url)
        let payload = try JSONDecoder().decode(ShWeek1Payload.self, from: data)
        let targetPhoneme = Phoneme(ipa: payload.target.phoneme)
        return ScriptedContentProvider(
            target: Grapheme(letters: payload.target.letters),
            taughtGraphemes: Set(payload.l2TaughtGraphemes.map(Grapheme.init(letters:))),
            words: payload.decodeWords.map { $0.asDecodeWord(targetPhoneme: targetPhoneme) },
            sentences: payload.sentences.map { $0.asDecodeSentence(targetPhoneme: targetPhoneme) }
        )
    }

    /// Resource filename prefix per v1 skill code. Extending v1 means adding
    /// a case here and a matching `*_week.json` under `Resources/`.
    private static func resourceName(for code: SkillCode) -> String? {
        switch code.rawValue {
        case "sh_onset": return "sh_week1"
        case "th_voiceless": return "th_week"
        case "f_onset": return "f_week"
        case "r_onset": return "r_week"
        case "short_a": return "short_a_week"
        default: return nil
        }
    }

    public static func bundled(for code: SkillCode) throws -> ScriptedContentProvider {
        guard let name = resourceName(for: code) else {
            throw ScriptedContentError.resourceMissing("bundled provider for \(code.rawValue)")
        }
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw ScriptedContentError.resourceMissing("\(name).json")
        }
        let data = try Data(contentsOf: url)
        let payload = try JSONDecoder().decode(ShWeek1Payload.self, from: data)
        let targetPhoneme = Phoneme(ipa: payload.target.phoneme)
        return ScriptedContentProvider(
            target: Grapheme(letters: payload.target.letters),
            taughtGraphemes: Set(payload.l2TaughtGraphemes.map(Grapheme.init(letters:))),
            words: payload.decodeWords.map { $0.asDecodeWord(targetPhoneme: targetPhoneme) },
            sentences: payload.sentences.map { $0.asDecodeSentence(targetPhoneme: targetPhoneme) }
        )
    }
}

public enum ScriptedContentError: Error, Equatable {
    case resourceMissing(String)
}

private struct ShWeek1Payload: Decodable {
    let target: TargetPayload
    let l2TaughtGraphemes: [String]
    let decodeWords: [WordPayload]
    let sentences: [SentencePayload]

    enum CodingKeys: String, CodingKey {
        case target
        case l2TaughtGraphemes = "l2_taught_graphemes"
        case decodeWords = "decode_words"
        case sentences
    }
}

private struct TargetPayload: Decodable {
    let letters: String
    let phoneme: String
}

private struct WordPayload: Decodable {
    let surface: String
    let graphemes: [String]
    let phonemes: [String]
    let note: String?

    func asDecodeWord(targetPhoneme: Phoneme?) -> DecodeWord {
        DecodeWord(
            word: Word(
                surface: surface,
                graphemes: graphemes.map(Grapheme.init(letters:)),
                phonemes: phonemes.map(Phoneme.init(ipa:)),
                targetPhoneme: targetPhoneme),
            note: note
        )
    }

    func asWord(targetPhoneme: Phoneme?) -> Word {
        Word(
            surface: surface,
            graphemes: graphemes.map(Grapheme.init(letters:)),
            phonemes: phonemes.map(Phoneme.init(ipa:)),
            targetPhoneme: targetPhoneme)
    }
}

private struct SentencePayload: Decodable {
    let text: String
    let words: [WordPayload]

    func asDecodeSentence(targetPhoneme: Phoneme?) -> DecodeSentence {
        DecodeSentence(text: text, words: words.map { $0.asWord(targetPhoneme: targetPhoneme) })
    }
}
