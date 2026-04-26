import Foundation
import MoraCore
import MoraEngines
import SwiftData
import SwiftUI
import XCTest

#if canImport(UIKit)
import UIKit
#endif

@testable import MoraUI

@MainActor
final class WeeklyIntroViewAudioTests: XCTestCase {
    #if canImport(UIKit)
    func testGreetClipPlaysOnceOnAppear() async throws {
        let store = try BundledYokaiStore()
        let player = RecordingClipPlayer()
        let player1Expectation = expectation(description: "greet plays once on appear")
        player.firstPlayExpectation = player1Expectation

        let yokai = try Self.makeYokaiOrchestrator(forID: "sh")
        let view = WeeklyIntroView(yokai: yokai, store: store, player: player)

        let window = UIWindow(frame: UIScreen.main.bounds)
        let host = UIHostingController(
            rootView:
                view.environment(
                    \.moraStrings,
                    JapaneseL1Profile().uiStrings(forAgeYears: 8)
                )
        )
        window.rootViewController = host
        window.makeKeyAndVisible()

        await fulfillment(of: [player1Expectation], timeout: 2.0)

        XCTAssertEqual(player.playedURLs.count, 1)
        XCTAssertEqual(
            player.playedURLs.first,
            store.voiceClipURL(for: "sh", clip: .greet)
        )

        window.isHidden = true
    }

    func testGreetClipStopsOnDisappear() async throws {
        let store = try BundledYokaiStore()
        let player = RecordingClipPlayer()
        let firstPlay = expectation(description: "greet plays on appear")
        player.firstPlayExpectation = firstPlay
        let yokai = try Self.makeYokaiOrchestrator(forID: "sh")
        let view = WeeklyIntroView(yokai: yokai, store: store, player: player)

        let window = UIWindow(frame: UIScreen.main.bounds)
        let host = UIHostingController(
            rootView:
                view.environment(
                    \.moraStrings,
                    JapaneseL1Profile().uiStrings(forAgeYears: 8)
                )
        )
        window.rootViewController = host
        window.makeKeyAndVisible()

        // Wait on `.task` rather than a fixed delay.
        await fulfillment(of: [firstPlay], timeout: 2.0)
        XCTAssertEqual(player.playedURLs.count, 1)
        XCTAssertEqual(player.stopCallCount, 0)

        window.rootViewController = UIHostingController(rootView: Color.clear)
        // Poll for `.onDisappear` to deliver the `player.stop()` call
        // rather than relying on a hard-coded sleep.
        try await waitUntil(timeout: 2.0) { player.stopCallCount >= 1 }

        XCTAssertGreaterThanOrEqual(player.stopCallCount, 1)
        window.isHidden = true
    }

    func testReplayButtonRefiresGreetClip() async throws {
        let store = try BundledYokaiStore()
        let player = RecordingClipPlayer()
        let firstPlay = expectation(description: "greet plays on appear")
        player.firstPlayExpectation = firstPlay
        let yokai = try Self.makeYokaiOrchestrator(forID: "sh")
        let inspector = WeeklyIntroViewTestHook()
        let view = WeeklyIntroView(yokai: yokai, store: store, player: player)
            .environment(\.weeklyIntroTestHook, inspector)

        let window = UIWindow(frame: UIScreen.main.bounds)
        let host = UIHostingController(
            rootView:
                view.environment(
                    \.moraStrings,
                    JapaneseL1Profile().uiStrings(forAgeYears: 8)
                )
        )
        window.rootViewController = host
        window.makeKeyAndVisible()

        await fulfillment(of: [firstPlay], timeout: 2.0)
        XCTAssertEqual(player.playedURLs.count, 1)

        // Simulate the user tapping the replay button.
        inspector.tapReplay?()
        // The closure stored on the hook hops through `Task { @MainActor in }`,
        // so the replay action runs after this synchronous frame yields. Yield
        // once so the assertions below observe the post-replay state.
        await Task.yield()

        XCTAssertEqual(player.playedURLs.count, 2)
        XCTAssertEqual(player.stopCallCount, 1, "replay should stop before re-playing")
        XCTAssertEqual(
            player.playedURLs.last,
            store.voiceClipURL(for: "sh", clip: .greet)
        )

        window.isHidden = true
    }
    #endif

    static func makeYokaiOrchestrator(forID yokaiID: String) throws -> YokaiOrchestrator {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let store = try BundledYokaiStore()
        let orch = YokaiOrchestrator(store: store, modelContext: ctx)
        try orch.startWeek(yokaiID: yokaiID, weekStart: Date())
        return orch
    }
}

#if canImport(UIKit)
/// Polls `condition` every 25 ms until it returns `true` or `timeout`
/// elapses. Avoids hard-coded sleeps that can flake on CI under load.
@MainActor
private func waitUntil(
    timeout: TimeInterval,
    condition: @MainActor () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() >= deadline { return }
        try await Task.sleep(for: .milliseconds(25))
    }
}
#endif

@MainActor
final class RecordingClipPlayer: YokaiClipPlayer {
    private(set) var playedURLs: [URL] = []
    private(set) var stopCallCount: Int = 0
    var firstPlayExpectation: XCTestExpectation?

    func play(url: URL) -> Bool {
        playedURLs.append(url)
        if playedURLs.count == 1 { firstPlayExpectation?.fulfill() }
        return true
    }

    func stop() {
        stopCallCount += 1
    }
}
