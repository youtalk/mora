import Foundation

public struct YokaiDefinition: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let grapheme: String
    public let ipa: String
    public let personality: String
    public let soundGesture: String
    public let wordDecor: [String]
    public let palette: [String]
    public let expression: String
    public let voice: Voice

    public init(
        id: String,
        grapheme: String,
        ipa: String,
        personality: String,
        soundGesture: String,
        wordDecor: [String],
        palette: [String],
        expression: String,
        voice: Voice
    ) {
        self.id = id
        self.grapheme = grapheme
        self.ipa = ipa
        self.personality = personality
        self.soundGesture = soundGesture
        self.wordDecor = wordDecor
        self.palette = palette
        self.expression = expression
        self.voice = voice
    }

    enum CodingKeys: String, CodingKey {
        case id, grapheme, ipa, personality
        case soundGesture = "sound_gesture"
        case wordDecor = "word_decor"
        case palette, expression, voice
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.grapheme = try container.decode(String.self, forKey: .grapheme)
        self.ipa = try container.decode(String.self, forKey: .ipa)
        self.personality = try container.decode(String.self, forKey: .personality)
        self.soundGesture = try container.decode(String.self, forKey: .soundGesture)
        self.wordDecor = try container.decode([String].self, forKey: .wordDecor)
        self.palette = try container.decode([String].self, forKey: .palette)
        self.expression = try container.decode(String.self, forKey: .expression)
        self.voice = try container.decode(Voice.self, forKey: .voice)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(grapheme, forKey: .grapheme)
        try container.encode(ipa, forKey: .ipa)
        try container.encode(personality, forKey: .personality)
        try container.encode(soundGesture, forKey: .soundGesture)
        try container.encode(wordDecor, forKey: .wordDecor)
        try container.encode(palette, forKey: .palette)
        try container.encode(expression, forKey: .expression)
        try container.encode(voice, forKey: .voice)
    }

    public struct Voice: Codable, Hashable, Sendable {
        public let characterDescription: String
        public let clips: [YokaiClipKey: String]

        public init(characterDescription: String, clips: [YokaiClipKey: String]) {
            self.characterDescription = characterDescription
            self.clips = clips
        }

        enum CodingKeys: String, CodingKey {
            case characterDescription = "character_description"
            case clips
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.characterDescription = try container.decode(String.self, forKey: .characterDescription)

            let clipsContainer = try container.nestedContainer(keyedBy: RawStringCodingKey.self, forKey: .clips)
            var clips: [YokaiClipKey: String] = [:]
            for key in clipsContainer.allKeys {
                if let yokaiKey = YokaiClipKey(rawValue: key.stringValue) {
                    clips[yokaiKey] = try clipsContainer.decode(String.self, forKey: key)
                }
            }
            self.clips = clips
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(characterDescription, forKey: .characterDescription)

            var clipsContainer = container.nestedContainer(keyedBy: RawStringCodingKey.self, forKey: .clips)
            for (key, value) in clips {
                try clipsContainer.encode(value, forKey: RawStringCodingKey(stringValue: key.rawValue))
            }
        }
    }
}

// Helper for encoding/decoding string-keyed dictionaries
private struct RawStringCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}
