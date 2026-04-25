import XCTest
import MoraTesting
@testable import MoraCore
@testable import MoraEngines

@MainActor
final class YokaiClipRouterTests: XCTestCase {
    func test_play_resolvesURLAndCallsPlayer() async {
        let store = FakeYokaiStore()
        let url = URL(fileURLWithPath: "/tmp/sh-phoneme.m4a")
        store.clipURLs["sh"] = [.phoneme: url]

        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: "sh",
            store: store,
            player: player,
            silencer: {}
        )

        let played = await router.play(.phoneme)

        XCTAssertTrue(played)
        XCTAssertEqual(player.playedURLs, [url])
    }

    func test_play_awaitsSilencerBeforePlayer() async {
        let store = FakeYokaiStore()
        let url = URL(fileURLWithPath: "/tmp/sh-encourage.m4a")
        store.clipURLs["sh"] = [.encourage: url]

        // Both the silencer and the player append into a shared MainActor
        // recorder; the test asserts the resulting order. The whole test class
        // is @MainActor so no concurrency safety wrapper is needed.
        let recorder = OrderRecorder()
        let player = TracingYokaiClipPlayer(recorder: recorder)
        let router = YokaiClipRouter(
            yokaiID: "sh",
            store: store,
            player: player,
            silencer: { recorder.append("silencer") }
        )

        _ = await router.play(.encourage)

        XCTAssertEqual(recorder.events, ["silencer", "player"])
    }

    func test_play_returnsFalseWhenClipURLMissing() async {
        let store = FakeYokaiStore()  // no clip URLs seeded
        let player = FakeYokaiClipPlayer()
        var silenced = false
        let router = YokaiClipRouter(
            yokaiID: "sh",
            store: store,
            player: player,
            silencer: { silenced = true }
        )

        let played = await router.play(.phoneme)

        XCTAssertFalse(played)
        XCTAssertTrue(player.playedURLs.isEmpty)
        XCTAssertFalse(silenced, "silencer should not run when clip URL is missing")
    }

    func test_recordCorrect_firesEncourageOnThirdConsecutiveCorrect() async {
        let store = FakeYokaiStore()
        let url = URL(fileURLWithPath: "/tmp/sh-encourage.m4a")
        store.clipURLs["sh"] = [.encourage: url]
        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: "sh", store: store, player: player, silencer: {}
        )

        await router.recordCorrect()
        await router.recordCorrect()
        XCTAssertTrue(player.playedURLs.isEmpty, "no clip until 3rd correct")

        await router.recordCorrect()
        XCTAssertEqual(player.playedURLs, [url], "encourage on 3rd correct")
    }

    func test_recordCorrect_streakResetsAfterEncourage() async {
        let store = FakeYokaiStore()
        let url = URL(fileURLWithPath: "/tmp/sh-encourage.m4a")
        store.clipURLs["sh"] = [.encourage: url]
        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: "sh", store: store, player: player, silencer: {}
        )

        for _ in 0..<6 {
            await router.recordCorrect()
        }

        XCTAssertEqual(player.playedURLs.count, 2, "two encourage clips for 6-correct run (3rd and 6th)")
    }

    func test_recordIncorrect_resetsStreakAndFiresGentleRetry() async {
        let store = FakeYokaiStore()
        let retry = URL(fileURLWithPath: "/tmp/sh-retry.m4a")
        store.clipURLs["sh"] = [.gentleRetry: retry]
        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: "sh", store: store, player: player, silencer: {}
        )

        await router.recordCorrect()
        await router.recordCorrect()
        await router.recordIncorrect()  // resets streak, fires retry (first miss)
        await router.recordCorrect()
        await router.recordCorrect()
        // Two more correct trials; would have been the third in the original
        // streak. Encourage must NOT fire because the wrong answer reset the count.
        XCTAssertEqual(player.playedURLs, [retry])
    }

    func test_recordIncorrect_throttlesGentleRetryToAtMostOnePerFiveTrials() async {
        let store = FakeYokaiStore()
        let retry = URL(fileURLWithPath: "/tmp/sh-retry.m4a")
        store.clipURLs["sh"] = [.gentleRetry: retry]
        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: "sh", store: store, player: player, silencer: {}
        )

        // T1: first miss → fires.
        await router.recordIncorrect()
        XCTAssertEqual(player.playedURLs.count, 1)

        // T2 / T3 / T4 / T5: still inside the throttle window
        // (trialIndex - lastGentleRetryTrialIndex < 5). All suppressed.
        for _ in 0..<4 {
            await router.recordIncorrect()
        }
        XCTAssertEqual(
            player.playedURLs.count, 1,
            "trials 2–5 are within the 5-trial throttle window after T1"
        )

        // T6: trialIndex - lastGentleRetryTrialIndex == 5 → fires again.
        await router.recordIncorrect()
        XCTAssertEqual(
            player.playedURLs.count, 2,
            "fires on the 5th trial after the previous retry (T6)"
        )
    }

    func test_recordIncorrect_correctTrialsCountTowardThrottleWindow() async {
        let store = FakeYokaiStore()
        let retry = URL(fileURLWithPath: "/tmp/sh-retry.m4a")
        let encourage = URL(fileURLWithPath: "/tmp/sh-encourage.m4a")
        store.clipURLs["sh"] = [.gentleRetry: retry, .encourage: encourage]
        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: "sh", store: store, player: player, silencer: {}
        )

        await router.recordIncorrect()  // trial 1, retry fires
        await router.recordCorrect()  // trial 2
        await router.recordCorrect()  // trial 3
        await router.recordCorrect()  // trial 4 — encourage fires (3 consecutive)
        await router.recordIncorrect()  // trial 5 — within throttle, retry suppressed
        XCTAssertEqual(player.playedURLs, [retry, encourage])

        await router.recordIncorrect()  // trial 6 — 5 trials elapsed, retry fires
        XCTAssertEqual(player.playedURLs, [retry, encourage, retry])
    }

    func test_stop_callsPlayerStop() async {
        let store = FakeYokaiStore()
        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: "sh", store: store, player: player, silencer: {}
        )

        router.stop()
        XCTAssertEqual(player.stopCallCount, 1)
    }
}

/// Test helper: ordered event log. Used only inside the @MainActor test class
/// so a plain reference type is safe — no cross-isolation appends.
@MainActor
final class OrderRecorder {
    private(set) var events: [String] = []
    func append(_ event: String) { events.append(event) }
}

/// Test player that logs `"player"` synchronously when `play(url:)` is called.
@MainActor
final class TracingYokaiClipPlayer: FakeYokaiClipPlayer {
    let recorder: OrderRecorder
    init(recorder: OrderRecorder) {
        self.recorder = recorder
        super.init()
    }
    override func play(url: URL) -> Bool {
        recorder.append("player")
        return super.play(url: url)
    }
}
