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
final class WeeklyIntroViewDismissTests: XCTestCase {
    #if canImport(UIKit)
    func testCTADismissesMondayIntroCutscene() async throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let store = try BundledYokaiStore()
        let yokai = YokaiOrchestrator(store: store, modelContext: ctx)
        try yokai.startWeek(yokaiID: "sh", weekStart: Date())
        XCTAssertNotNil(yokai.activeCutscene)
        XCTAssertTrue(yokai.activeCutscene?.isMondayIntro ?? false)

        let player = SilentClipPlayer()
        let hook = WeeklyIntroViewTestHook()
        let view = WeeklyIntroView(yokai: yokai, store: store, player: player)
            .environment(\.weeklyIntroTestHook, hook)
            .environment(
                \.moraStrings,
                JapaneseL1Profile().uiStrings(forAgeYears: 8)
            )

        let window = UIWindow(frame: UIScreen.main.bounds)
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()

        // Wait for `.task` to publish the dismiss closure. Poll briefly
        // rather than `Task.sleep` so the test does not depend on a
        // fixed delay under CI load.
        try await waitUntil(timeout: 2.0) { hook.tapNext != nil }
        XCTAssertNotNil(hook.tapNext, "WeeklyIntroView must publish its CTA action")

        hook.tapNext?()
        // The closure stored on the hook hops through `Task { @MainActor in }`,
        // so the dismiss action runs after this synchronous frame yields. Yield
        // once so the assertion below observes the post-dismiss state.
        await Task.yield()

        XCTAssertNil(yokai.activeCutscene, "CTA should clear the cutscene")
        window.isHidden = true
    }
    #endif
}

@MainActor
private final class SilentClipPlayer: YokaiClipPlayer {
    func play(url: URL) -> Bool { true }
    func stop() {}
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
