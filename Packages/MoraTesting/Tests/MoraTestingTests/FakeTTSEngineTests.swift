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

    func test_speak_honorsTaskCancellation() async {
        // Capture the real async-engine contract SpeechController relies on:
        // a parent task that cancels the child during speak must see the
        // sequence stop, not run to completion. A fake that can't reproduce
        // this leaves us unable to test the root-cause fix for the
        // cross-screen audio bug.
        let tts = FakeTTSEngine(speakDuration: .milliseconds(80))
        let outer = Task {
            await tts.speak("a")
            if Task.isCancelled { return }
            await tts.speak("b")
        }
        try? await Task.sleep(for: .milliseconds(20))
        outer.cancel()
        await outer.value
        XCTAssertEqual(tts.uttered, ["a"])
    }
}
