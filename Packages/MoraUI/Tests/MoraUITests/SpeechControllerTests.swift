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
            .text("a", .slow), .text("b", .slow), .text("c", .normal),
        ])
        await task.value

        XCTAssertEqual(fake.uttered, ["a", "b", "c"])
    }

    func test_play_stopsRemainingPromptsWhenReplaced() async {
        let fake = FakeTTSEngine(speakDuration: .milliseconds(200))
        let controller = SpeechController(tts: fake)

        let first = controller.play([
            .text("first-1", .slow), .text("first-2", .slow), .text("first-3", .slow),
        ])
        // Wait until the controller's loop has reached "first-1" and
        // recorded it in the fake, before replacing the sequence. A fixed
        // sleep here would be flaky on slow CI runners (the Task may not
        // have scheduled yet); polling lets us tolerate load while still
        // failing fast if the engine never records anything.
        let started = await waitUntil { fake.uttered.contains("first-1") }
        XCTAssertTrue(started, "timed out waiting for first-1 to start")
        let second = controller.play([.text("second-1", .slow)])
        await first.value
        await second.value

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
        let fake = FakeTTSEngine(speakDuration: .milliseconds(200))
        let controller = SpeechController(tts: fake)

        let task = controller.play([
            .text("a", .slow), .text("b", .slow), .text("c", .slow),
        ])
        let started = await waitUntil { fake.uttered.contains("a") }
        XCTAssertTrue(started, "timed out waiting for a to start")
        await controller.stop()
        await task.value

        XCTAssertEqual(fake.uttered, ["a"])
        // `stop()` awaits `tts.stop()`, so the fake's stop counter is
        // deterministically 1 by the time this line executes.
        XCTAssertEqual(fake.stopCount, 1)
    }

    func test_playAndAwait_propagatesCallerCancellation() async {
        let fake = FakeTTSEngine(speakDuration: .milliseconds(200))
        let controller = SpeechController(tts: fake)

        let outer = Task { @MainActor in
            await controller.playAndAwait([
                .text("x", .slow), .text("y", .slow), .text("z", .slow),
            ])
        }
        let started = await waitUntil { fake.uttered.contains("x") }
        XCTAssertTrue(started, "timed out waiting for x to start")
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

        await controller.play([.phoneme(phoneme, .slow)]).value

        XCTAssertEqual(fake.uttered, ["<phoneme: ʃ>"])
    }
}

/// Polls `condition` every 5ms up to `timeout`. Returns whether the
/// condition became true. Used by tests that need to synchronize on a
/// background task reaching a known state without baking in a fixed
/// sleep (which is flaky under CI load).
@Sendable
private func waitUntil(
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
