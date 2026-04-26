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

        // Wait for `.task` to publish the dismiss closure.
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertNotNil(hook.tapNext, "WeeklyIntroView must publish its CTA action")

        hook.tapNext?()

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
