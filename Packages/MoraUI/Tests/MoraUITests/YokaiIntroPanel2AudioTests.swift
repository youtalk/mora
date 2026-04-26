// Packages/MoraUI/Tests/MoraUITests/YokaiIntroPanel2AudioTests.swift
import Foundation
import MoraCore
import MoraEngines
import SwiftUI
import XCTest

@testable import MoraUI

@MainActor
final class FakeYokaiClipPlayer: YokaiClipPlayer {
    private(set) var playedURLs: [URL] = []
    private(set) var stopCount: Int = 0

    func play(url: URL) -> Bool {
        playedURLs.append(url)
        return true
    }

    func stop() {
        stopCount += 1
    }
}

#if canImport(UIKit)
@MainActor
final class YokaiIntroPanel2AudioTests: XCTestCase {
    func testPlayingTodaysYokaiPanelTriggersGreetClipExactlyOnce() async throws {
        let store = try BundledYokaiStore()
        let player = FakeYokaiClipPlayer()
        let panel = TodaysYokaiPanel(store: store, player: player, onContinue: {})

        let host = UIHostingController(
            rootView:
                panel.environment(
                    \.moraStrings,
                    JapaneseL1Profile().uiStrings(forAgeYears: 8)
                )
        )
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()

        // Allow `.task` to run.
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(player.playedURLs.count, 1, "greet clip should fire once on appear")
        let firstYokaiID = CurriculumEngine.sharedV1.skills.first?.yokaiID
        XCTAssertNotNil(firstYokaiID)
        let expectedURL = store.voiceClipURL(for: firstYokaiID!, clip: .greet)
        XCTAssertEqual(player.playedURLs.first, expectedURL)
    }
}
#endif
