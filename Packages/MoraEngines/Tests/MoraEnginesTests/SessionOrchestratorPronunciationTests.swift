import MoraCore
import XCTest

@testable import MoraEngines

@MainActor
final class SessionOrchestratorPronunciationTests: XCTestCase {

    func testDecodingRecordsPhonemeTrialAssessmentFromEvaluator() async {
        try XCTSkip("Tile-board decoding wiring lands in 18b")
    }
}

extension Target {
    static func dummyForShipTests() -> Target {
        let skill = Skill(
            code: "sh_onset", level: .l3, displayName: "sh",
            graphemePhoneme: .init(
                grapheme: .init(letters: "sh"),
                phoneme: .init(ipa: "ʃ")
            )
        )
        return Target(weekStart: Date(), skill: skill)
    }
}

extension SessionOrchestrator {
    func advanceToDecodingForTests() async {
        if let g = target.skill.graphemePhoneme?.grapheme {
            await handle(.warmupTap(g))
        }
        await handle(.advance)
    }
}
