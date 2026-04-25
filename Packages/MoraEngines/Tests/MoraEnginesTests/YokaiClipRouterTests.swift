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
