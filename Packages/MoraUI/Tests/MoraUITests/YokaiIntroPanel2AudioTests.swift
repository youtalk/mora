// Packages/MoraUI/Tests/MoraUITests/YokaiIntroPanel2AudioTests.swift
import Foundation
import MoraCore
import MoraEngines
import SwiftUI
import XCTest

#if canImport(UIKit)
import UIKit
#endif

@testable import MoraUI

@MainActor
final class FakeYokaiClipPlayer: YokaiClipPlayer {
    private(set) var playedURLs: [URL] = []
    private(set) var stopCount: Int = 0

    /// Optional expectation fulfilled the first time `play(url:)` is called,
    /// so tests can wait on `.task` firing without a hard-coded sleep.
    var firstPlayExpectation: XCTestExpectation?

    func play(url: URL) -> Bool {
        playedURLs.append(url)
        if playedURLs.count == 1 {
            firstPlayExpectation?.fulfill()
        }
        return true
    }

    func stop() {
        stopCount += 1
    }
}

@MainActor
final class YokaiIntroPanel2AudioTests: XCTestCase {
    #if canImport(UIKit)
    func testPlayingTodaysYokaiPanelTriggersGreetClipExactlyOnce() async throws {
        let store = try BundledYokaiStore()
        let player = FakeYokaiClipPlayer()
        let playExpectation = expectation(description: "greet clip plays once on appear")
        player.firstPlayExpectation = playExpectation
        let panel = TodaysYokaiPanel(store: store, player: player, onContinue: {})

        // Hosting the panel inside a real UIWindow lets SwiftUI's lifecycle
        // fire `.task` reliably (just `loadViewIfNeeded()` does not always
        // deliver `.task` on detached hosting controllers).
        let window = UIWindow(frame: UIScreen.main.bounds)
        let host = UIHostingController(
            rootView:
                panel.environment(
                    \.moraStrings,
                    JapaneseL1Profile().uiStrings(at: .advanced)
                )
        )
        window.rootViewController = host
        window.makeKeyAndVisible()

        await fulfillment(of: [playExpectation], timeout: 2.0)

        XCTAssertEqual(player.playedURLs.count, 1, "greet clip should fire once on appear")
        let firstYokaiID = CurriculumEngine.sharedV1.skills.first?.yokaiID
        XCTAssertNotNil(firstYokaiID)
        let expectedURL = store.voiceClipURL(for: firstYokaiID!, clip: .greet)
        XCTAssertEqual(player.playedURLs.first, expectedURL)

        window.isHidden = true
    }

    func testTodaysYokaiPanelStopsGreetClipOnDisappear() async throws {
        let store = try BundledYokaiStore()
        let player = FakeYokaiClipPlayer()
        let panel = TodaysYokaiPanel(store: store, player: player, onContinue: {})

        // Hosting the panel inside a real UIWindow lets SwiftUI's lifecycle
        // fire `.onDisappear` when the window's rootViewController is swapped
        // out, which is the contract Panel 2 relies on for greet-clip cleanup
        // (spec C4).
        let window = UIWindow(frame: UIScreen.main.bounds)
        let host = UIHostingController(
            rootView:
                panel.environment(
                    \.moraStrings,
                    JapaneseL1Profile().uiStrings(at: .advanced)
                )
        )
        window.rootViewController = host
        window.makeKeyAndVisible()

        // Allow `.task` to run and play the greet clip.
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(player.playedURLs.count, 1, "greet clip should fire once on appear")
        XCTAssertEqual(player.stopCount, 0, "stop should not fire while the panel is on screen")

        // Swap the window's root to a placeholder view to trigger
        // `.onDisappear` on the panel.
        window.rootViewController = UIHostingController(rootView: Color.clear)

        // Wait for the SwiftUI runloop to deliver the disappearance event.
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertGreaterThanOrEqual(
            player.stopCount,
            1,
            "panel should stop the greet clip when it disappears (spec C4)"
        )

        window.isHidden = true
    }
    #endif
}
