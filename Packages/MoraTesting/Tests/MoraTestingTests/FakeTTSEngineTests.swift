import MoraCore
import MoraEngines
import XCTest

@testable import MoraTesting

final class FakeTTSEngineTests: XCTestCase {
    func test_speak_recordsUtterance() async {
        let tts = FakeTTSEngine()
        await tts.speak("hello")
        XCTAssertEqual(tts.uttered, ["hello"])
    }

    func test_speakPhoneme_recordsIPA() async {
        let tts = FakeTTSEngine()
        await tts.speak(phoneme: Phoneme(ipa: "ʃ"))
        XCTAssertEqual(tts.uttered, ["<phoneme: ʃ>"])
    }

    func test_reset_clearsHistory() async {
        let tts = FakeTTSEngine()
        await tts.speak("a")
        tts.reset()
        XCTAssertTrue(tts.uttered.isEmpty)
    }

    func test_stop_incrementsStopCount() async {
        let tts = FakeTTSEngine()
        XCTAssertEqual(tts.stopCount, 0)
        await tts.stop()
        XCTAssertEqual(tts.stopCount, 1)
        await tts.stop()
        XCTAssertEqual(tts.stopCount, 2)
    }

    func test_reset_clearsStopCount() async {
        let tts = FakeTTSEngine()
        await tts.stop()
        await tts.stop()
        XCTAssertEqual(tts.stopCount, 2)
        tts.reset()
        XCTAssertEqual(tts.stopCount, 0)
    }
}
