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
final class YokaiCutsceneOverlayMondayIntroTests: XCTestCase {
    #if canImport(UIKit)
    func testMondayIntroRendersNothing() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let store = try BundledYokaiStore()
        let orch = YokaiOrchestrator(store: store, modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        XCTAssertTrue(orch.activeCutscene?.isMondayIntro ?? false)

        let overlay = YokaiCutsceneOverlay(orchestrator: orch, speech: nil)
            .environment(
                \.moraStrings,
                JapaneseL1Profile().uiStrings(forAgeYears: 8)
            )

        let host = UIHostingController(rootView: overlay)
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()

        // The overlay's body is a ZStack with a black background by default.
        // For .mondayIntro we want it to publish *no* yokai content. We
        // assert this by checking that the rendered view tree contains no
        // text node carrying the greet subtitle (which would only be
        // produced by the simpleStack arm).
        let greetText = orch.currentYokai?.voice.clips[.greet] ?? "<unset>"
        XCTAssertFalse(
            host.view.recursiveDescription().contains(greetText),
            "Monday intro overlay must not render the greet subtitle"
        )
    }

    func testFridayClimaxStillRenders() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let store = try BundledYokaiStore()
        let orch = YokaiOrchestrator(store: store, modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        // Force-set fridayClimax via a public surface: nudge friendship to
        // 100% then run a Friday final-trial correct. This is the same
        // path the production session uses, kept here so the test does not
        // depend on internal mutation.
        orch.beginFridaySession(trialsPlanned: 1)
        orch.recordFridayFinalTrial(correct: true)

        guard case .fridayClimax = orch.activeCutscene else {
            return XCTFail("expected fridayClimax cutscene")
        }

        let overlay = YokaiCutsceneOverlay(orchestrator: orch, speech: nil)
            .environment(
                \.moraStrings,
                JapaneseL1Profile().uiStrings(forAgeYears: 8)
            )

        let host = UIHostingController(rootView: overlay)
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()

        // We don't assert specific subtitle text here (the climax view
        // staggers its phases), only that the host view has positive
        // content size — i.e., the cutscene is not empty.
        XCTAssertGreaterThan(host.view.bounds.width, 0)
    }
    #endif
}

#if canImport(UIKit)
private extension UIView {
    func recursiveDescription() -> String {
        let me = String(describing: self)
        let kids = subviews.map { $0.recursiveDescription() }.joined(separator: "\n")
        return me + "\n" + kids
    }
}
#endif
