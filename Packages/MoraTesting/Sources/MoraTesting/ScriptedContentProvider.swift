import Foundation
import MoraCore
import MoraEngines

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
        return ScriptedContentProvider(
            target: Grapheme(letters: payload.target.letters),
            taughtGraphemes: Set(payload.l2TaughtGraphemes.map(Grapheme.init(letters:))),
            words: payload.decodeWords.map { $0.asDecodeWord() },
            sentences: payload.sentences.map { $0.asDecodeSentence() }
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

    func asDecodeWord() -> DecodeWord {
        DecodeWord(
            word: Word(
                surface: surface,
                graphemes: graphemes.map(Grapheme.init(letters:)),
                phonemes: phonemes.map(Phoneme.init(ipa:))),
            note: note
        )
    }

    func asWord() -> Word {
        Word(
            surface: surface,
            graphemes: graphemes.map(Grapheme.init(letters:)),
            phonemes: phonemes.map(Phoneme.init(ipa:)))
    }
}

private struct SentencePayload: Decodable {
    let text: String
    let words: [WordPayload]

    func asDecodeSentence() -> DecodeSentence {
        DecodeSentence(text: text, words: words.map { $0.asWord() })
    }
}
