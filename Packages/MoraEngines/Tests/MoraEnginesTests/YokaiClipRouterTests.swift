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

    func test_playAndAwait_resolvesURLAndCallsPlayer() async {
        let store = FakeYokaiStore()
        let url = URL(fileURLWithPath: "/tmp/sh-ex1.m4a")
        store.clipURLs["sh"] = [.example1: url]

        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: "sh",
            store: store,
            player: player,
            silencer: {}
        )

        let finished = await router.playAndAwait(.example1)

        XCTAssertTrue(finished)
        XCTAssertEqual(player.playedURLs, [url])
    }

    func test_playAndAwait_awaitsSilencerBeforePlayer() async {
        let store = FakeYokaiStore()
        let url = URL(fileURLWithPath: "/tmp/sh-ex2.m4a")
        store.clipURLs["sh"] = [.example2: url]

        let recorder = OrderRecorder()
        let player = TracingYokaiClipPlayer(recorder: recorder)
        let router = YokaiClipRouter(
            yokaiID: "sh",
            store: store,
            player: player,
            silencer: { recorder.append("silencer") }
        )

        _ = await router.playAndAwait(.example2)

        XCTAssertEqual(recorder.events, ["silencer", "player"])
    }

    func test_playAndAwait_returnsFalseWhenClipURLMissing() async {
        let store = FakeYokaiStore()  // no clip URLs seeded
        let player = FakeYokaiClipPlayer()
        var silenced = false
        let router = YokaiClipRouter(
            yokaiID: "sh",
            store: store,
            player: player,
            silencer: { silenced = true }
        )

        let finished = await router.playAndAwait(.example1)

        XCTAssertFalse(finished)
        XCTAssertTrue(player.playedURLs.isEmpty)
        XCTAssertFalse(silenced, "silencer should not run when clip URL is missing")
    }

    func test_playAndAwait_skipsPlayerWhenCancelledDuringSilencer() async {
        let store = FakeYokaiStore()
        let url = URL(fileURLWithPath: "/tmp/sh-ex3.m4a")
        store.clipURLs["sh"] = [.example3: url]

        let player = FakeYokaiClipPlayer()
        // Spawn a task that we cancel before the silencer's await suspension
        // resumes — emulates a SwiftUI .task being cancelled while the
        // router is mid-flight. The silencer below yields once so the
        // cancellation lands while the router is suspended on `await`.
        let router = YokaiClipRouter(
            yokaiID: "sh",
            store: store,
            player: player,
            silencer: { await Task.yield() }
        )

        let task = Task { @MainActor in
            await router.playAndAwait(.example3)
        }
        task.cancel()
        let finished = await task.value

        XCTAssertFalse(finished, "cancelled task should not start playback")
        XCTAssertTrue(
            player.playedURLs.isEmpty, "player must not be invoked when cancelled post-silencer"
        )
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

    func test_recordIncorrect_firesGentleRetryOnEveryMiss() async {
        let store = FakeYokaiStore()
        let retry = URL(fileURLWithPath: "/tmp/sh-retry.m4a")
        store.clipURLs["sh"] = [.gentleRetry: retry]
        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: "sh", store: store, player: player, silencer: {}
        )

        // Every dictation miss fires the encouragement clip — the throttle
        // was removed so the learner always gets a yokai response on a
        // wrong answer.
        for _ in 0..<5 {
            await router.recordIncorrect()
        }
        XCTAssertEqual(player.playedURLs, Array(repeating: retry, count: 5))
    }

    func test_recordIncorrect_doesNotSuppressEncourageBetweenMisses() async {
        let store = FakeYokaiStore()
        let retry = URL(fileURLWithPath: "/tmp/sh-retry.m4a")
        let encourage = URL(fileURLWithPath: "/tmp/sh-encourage.m4a")
        store.clipURLs["sh"] = [.gentleRetry: retry, .encourage: encourage]
        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: "sh", store: store, player: player, silencer: {}
        )

        await router.recordIncorrect()  // retry
        await router.recordCorrect()
        await router.recordCorrect()
        await router.recordCorrect()  // 3 consecutive → encourage
        await router.recordIncorrect()  // retry again — no throttle
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

    func test_typicalTuesdaySessionFiresAllSixSessionInternalClips() async {
        let store = FakeYokaiStore()
        let yokai = "sh"
        store.clipURLs[yokai] = [
            .phoneme: URL(fileURLWithPath: "/tmp/sh-phoneme.m4a"),
            .example1: URL(fileURLWithPath: "/tmp/sh-ex1.m4a"),
            .example2: URL(fileURLWithPath: "/tmp/sh-ex2.m4a"),
            .example3: URL(fileURLWithPath: "/tmp/sh-ex3.m4a"),
            .encourage: URL(fileURLWithPath: "/tmp/sh-encourage.m4a"),
            .gentleRetry: URL(fileURLWithPath: "/tmp/sh-retry.m4a"),
        ]
        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: yokai, store: store, player: player, silencer: {}
        )

        // Warmup
        await router.play(.phoneme)
        // Decoding (10 trials, examples at indices 0/3/7)
        await router.play(.example1)
        await router.play(.example2)
        await router.play(.example3)
        // Short sentences: 3 correct → encourage; 1 wrong → retry
        await router.recordCorrect()
        await router.recordCorrect()
        await router.recordCorrect()
        await router.recordIncorrect()

        let lastComponents = player.playedURLs.map { $0.lastPathComponent }
        XCTAssertEqual(
            Set(lastComponents),
            ["sh-phoneme.m4a", "sh-ex1.m4a", "sh-ex2.m4a", "sh-ex3.m4a", "sh-encourage.m4a", "sh-retry.m4a"]
        )
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
