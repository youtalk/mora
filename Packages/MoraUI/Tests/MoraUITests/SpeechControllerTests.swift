import MoraCore
import MoraEngines
import MoraTesting
import XCTest

@testable import MoraUI

/// Regression coverage for the phase-transition TTS bug: a `.task`-driven
/// speech loop must not keep issuing prompts after its view disappears,
/// and button-triggered fire-and-forget speech must be cancellable when
/// the session advances phase. Every case uses `FakeTTSEngine` with a
/// simulated speak duration so we can cancel mid-sequence and assert on
/// what was (and wasn't) actually queued.
@MainActor
final class SpeechControllerTests: XCTestCase {
    func test_play_speaksPromptsInOrder() async {
        let fake = FakeTTSEngine()
        let controller = SpeechController(tts: fake)

        let task = controller.play([
            .text("a"), .text("b"), .text("c"),
        ])
        await task.value

        XCTAssertEqual(fake.uttered, ["a", "b", "c"])
    }

    func test_play_stopsRemainingPromptsWhenReplaced() async {
        let fake = FakeTTSEngine(speakDuration: .milliseconds(80))
        let controller = SpeechController(tts: fake)

        let first = controller.play([
            .text("first-1"), .text("first-2"), .text("first-3"),
        ])
        // Give the loop time to enter speak("first-1") but not to advance.
        try? await Task.sleep(for: .milliseconds(20))
        let second = controller.play([.text("second-1")])
        await first.value
        await second.value

        // `first-1` already recorded (speak ran its entry); `second-1`
        // ran to completion. `first-2` / `first-3` must NOT be recorded:
        // the controller's cancel prevented the loop from advancing.
        XCTAssertTrue(fake.uttered.contains("first-1"))
        XCTAssertTrue(fake.uttered.contains("second-1"))
        XCTAssertFalse(
            fake.uttered.contains("first-2"),
            "A replaced sequence must not continue after its cancel — "
                + "otherwise the previous screen's audio bleeds onto the next."
        )
        XCTAssertFalse(fake.uttered.contains("first-3"))
    }

    func test_stop_cancelsInflightAndPreventsFurtherPrompts() async {
        let fake = FakeTTSEngine(speakDuration: .milliseconds(80))
        let controller = SpeechController(tts: fake)

        let task = controller.play([
            .text("a"), .text("b"), .text("c"),
        ])
        try? await Task.sleep(for: .milliseconds(20))
        controller.stop()
        await task.value

        // `a` got recorded before stop landed; everything after should have
        // been skipped by the `Task.isCancelled` check in the loop.
        XCTAssertEqual(fake.uttered, ["a"])
    }

    func test_playAndAwait_propagatesCallerCancellation() async {
        let fake = FakeTTSEngine(speakDuration: .milliseconds(80))
        let controller = SpeechController(tts: fake)

        let outer = Task { @MainActor in
            await controller.playAndAwait([
                .text("x"), .text("y"), .text("z"),
            ])
        }
        try? await Task.sleep(for: .milliseconds(20))
        outer.cancel()
        await outer.value

        // Cancelling the caller's `.task`-equivalent Task aborts the
        // sequence — the same guarantee SwiftUI relies on when a view
        // disappears mid-playback.
        XCTAssertTrue(fake.uttered.contains("x"))
        XCTAssertFalse(fake.uttered.contains("y"))
        XCTAssertFalse(fake.uttered.contains("z"))
    }

    func test_play_emitsPhonemePrompts() async {
        let fake = FakeTTSEngine()
        let controller = SpeechController(tts: fake)
        let phoneme = Phoneme(ipa: "ʃ")

        await controller.play([.phoneme(phoneme)]).value

        XCTAssertEqual(fake.uttered, ["<phoneme: ʃ>"])
    }
}
