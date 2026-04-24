import XCTest
@testable import MoraCore

final class YokaiDefinitionTests: XCTestCase {
    func test_decodesCanonicalJSON() throws {
        let json = """
        {
            "id": "sh",
            "grapheme": "sh",
            "ipa": "/ʃ/",
            "personality": "mischievous whisper spirit",
            "sound_gesture": "finger to lips",
            "word_decor": ["sailor hat", "seashell ears", "fin tail"],
            "palette": ["teal", "cream"],
            "expression": "playful smirk",
            "voice": {
                "character_description": "young whispery",
                "clips": {
                    "phoneme": "Shhh /ʃ/",
                    "example_1": "ship",
                    "example_2": "shop",
                    "example_3": "shell",
                    "greet": "Shhh",
                    "encourage": "Yes",
                    "gentle_retry": "Again",
                    "friday_acknowledge": "Yours"
                }
            }
        }
        """
        let data = Data(json.utf8)
        let yokai = try JSONDecoder().decode(YokaiDefinition.self, from: data)
        XCTAssertEqual(yokai.id, "sh")
        XCTAssertEqual(yokai.grapheme, "sh")
        XCTAssertEqual(yokai.ipa, "/ʃ/")
        XCTAssertEqual(yokai.wordDecor.count, 3)
        XCTAssertEqual(yokai.voice.clips[.phoneme], "Shhh /ʃ/")
        XCTAssertEqual(yokai.voice.clips[.example1], "ship")
        XCTAssertEqual(yokai.voice.clips[.fridayAcknowledge], "Yours")
    }
}
