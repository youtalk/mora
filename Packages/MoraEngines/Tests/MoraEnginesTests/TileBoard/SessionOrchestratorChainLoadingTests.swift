import XCTest
import MoraCore
@testable import MoraEngines

@MainActor
final class SessionOrchestratorChainLoadingTests: XCTestCase {
    private func makeOrchestrator() -> SessionOrchestrator {
        let skill = Skill(
            code: "sh_onset", level: .l3, displayName: "sh",
            graphemePhoneme: .init(grapheme: .init(letters: "sh"), phoneme: .init(ipa: "ʃ"))
        )
        return SessionOrchestrator(
            target: Target(weekStart: Date(), skill: skill),
            taughtGraphemes: FixtureWordChains.shInventory(),
            warmupOptions: [.init(letters: "s"), .init(letters: "sh"), .init(letters: "ch")],
            chainProvider: InMemoryWordChainProvider(phase: FixtureWordChains.shPhase()),
            sentences: [],
            assessment: AssessmentEngine(l1Profile: JapaneseL1Profile()),
            clock: { Date(timeIntervalSince1970: 0) }
        )
    }

    func testEnteringDecodingLoadsThreeChains() async {
        let o = makeOrchestrator()
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        await o.handle(.advance)
        XCTAssertEqual(o.phase, .decoding)
        XCTAssertEqual(o.pendingChains.count, 3)
        XCTAssertEqual(o.currentChainRole, .warmup)
        XCTAssertNotNil(o.currentTileBoardEngine)
        XCTAssertEqual(o.chainPipStates.count, 12)
        XCTAssertTrue(o.chainPipStates.allSatisfy { $0 == .pending || $0 == .active })
    }
}
