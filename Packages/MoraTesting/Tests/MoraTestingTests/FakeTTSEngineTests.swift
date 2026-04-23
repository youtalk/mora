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

    func test_speak_honorsTaskCancellation() async {
        // Capture the real async-engine contract SpeechController relies on:
        // a parent task that cancels the child during speak must see the
        // sequence stop, not run to completion. A fake that can't reproduce
        // this leaves us unable to test the root-cause fix for the
        // cross-screen audio bug.
        let tts = FakeTTSEngine(speakDuration: .milliseconds(200))
        let outer = Task {
            await tts.speak("a")
            if Task.isCancelled { return }
            await tts.speak("b")
        }
        // Poll until "a" is actually recorded (the child task started
        // executing its first speak). A fixed sleep would be flaky on slow
        // CI runners — the bounded timeout keeps us tolerant of load while
        // still failing fast if something is genuinely broken.
        let started = await waitUntil { tts.uttered.contains("a") }
        XCTAssertTrue(started, "timed out waiting for FakeTTSEngine to record 'a'")
        outer.cancel()
        await outer.value
        XCTAssertEqual(tts.uttered, ["a"])
    }
}

/// Polls `condition` every 5ms up to `timeout`. Returns whether the
/// condition became true. Used by tests that need to synchronize on a
/// background task reaching a known state without baking in a fixed
/// sleep (which is flaky under CI load).
@Sendable
func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: @Sendable () -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while !condition() {
        if ContinuousClock.now >= deadline { return false }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return true
}
