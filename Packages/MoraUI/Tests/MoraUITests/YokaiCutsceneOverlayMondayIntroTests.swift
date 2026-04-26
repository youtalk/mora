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
    func testMondayIntroRendersNothing() async throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let store = try BundledYokaiStore()
        let orch = YokaiOrchestrator(store: store, modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        XCTAssertTrue(orch.activeCutscene?.isMondayIntro ?? false)

        let overlay = YokaiCutsceneOverlay(orchestrator: orch, speech: nil)
            .environment(
                \.moraStrings,
                JapaneseL1Profile().uiStrings(at: .advanced)
            )

        // Mount in a real UIWindow so SwiftUI's lifecycle (.task / layout)
        // actually runs; a detached UIHostingController does not always
        // deliver these.
        let window = UIWindow(frame: UIScreen.main.bounds)
        let host = UIHostingController(rootView: overlay)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(50))

        // For `.mondayIntro` the overlay's body collapses to an empty
        // ZStack — no Color.black tint and no content. Verify by walking
        // the rendered UIView tree and asserting no descendant carries
        // the cutscene-content accessibility identifier (which marks
        // the simpleStack and fridayClimax wrappers).
        let hasContent = host.view.containsAccessibilityIdentifier(
            YokaiCutsceneOverlay.contentIdentifier
        )
        XCTAssertFalse(
            hasContent,
            "Monday intro overlay must not render any cutscene content"
        )

        window.isHidden = true
    }

    func testFridayClimaxStillRenders() async throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let store = try BundledYokaiStore()
        let orch = YokaiOrchestrator(store: store, modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        // Drive the orchestrator to `.fridayClimax` through its public
        // surface: begin a Friday session with a single planned trial,
        // then record that trial correct. The friendship floor-boost
        // fills the gauge to 100% on the final trial, which fires
        // `finalizeFridayIfNeeded()` and sets `activeCutscene =
        // .fridayClimax`.
        orch.beginFridaySession(trialsPlanned: 1)
        orch.recordFridayFinalTrial(correct: true)

        guard case .fridayClimax = orch.activeCutscene else {
            return XCTFail("expected fridayClimax cutscene")
        }

        let overlay = YokaiCutsceneOverlay(orchestrator: orch, speech: nil)
            .environment(
                \.moraStrings,
                JapaneseL1Profile().uiStrings(at: .advanced)
            )

        let window = UIWindow(frame: UIScreen.main.bounds)
        let host = UIHostingController(rootView: overlay)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(50))

        // The climax stack carries the cutscene-content accessibility
        // identifier. Asserting on its presence is meaningful coverage
        // even though the climax view staggers in over multiple phases
        // — the wrapper VStack mounts immediately at phase 0.
        let hasContent = host.view.containsAccessibilityIdentifier(
            YokaiCutsceneOverlay.contentIdentifier
        )
        XCTAssertTrue(
            hasContent,
            "Friday climax overlay must render its cutscene content"
        )

        window.isHidden = true
    }
    #endif
}

#if canImport(UIKit)
extension UIView {
    /// Recursively walks the receiver and its descendants looking for a
    /// view that carries the given accessibility identifier. SwiftUI's
    /// `accessibilityIdentifier(_:)` modifier surfaces through this
    /// property on the backing UIKit view, so this is a reliable test
    /// seam — unlike `String(describing:)` of `UIView`, which does not
    /// include rendered text or modifier metadata.
    fileprivate func containsAccessibilityIdentifier(_ identifier: String) -> Bool {
        if accessibilityIdentifier == identifier { return true }
        return subviews.contains { $0.containsAccessibilityIdentifier(identifier) }
    }
}
#endif
