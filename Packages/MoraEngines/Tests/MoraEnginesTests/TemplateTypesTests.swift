import XCTest
import MoraCore
@testable import MoraEngines

final class TemplateTypesTests: XCTestCase {
    func test_template_hasSkeletonAndSlotKinds() {
        let t = Template(
            skeleton: "The {subject} can {verb}.",
            slotKinds: ["subject": .subject, "verb": .verb]
        )
        XCTAssertEqual(t.skeleton, "The {subject} can {verb}.")
        XCTAssertEqual(t.slotKinds["subject"], .subject)
    }

    func test_vocabularyItem_tracksInterestAndSlotKinds() {
        let w = Word(surface: "ship",
                     graphemes: [.init(letters: "sh"), .init(letters: "i"), .init(letters: "p")],
                     phonemes: [.init(ipa: "ʃ"), .init(ipa: "ɪ"), .init(ipa: "p")])
        let v = VocabularyItem(
            word: w,
            slotKinds: [.subject, .noun],
            interest: InterestCategory(key: "vehicles", displayName: "Vehicles")
        )
        XCTAssertTrue(v.slotKinds.contains(.subject))
        XCTAssertEqual(v.interest?.key, "vehicles")
    }

    func test_slotKind_isCaseIterable() {
        XCTAssertTrue(SlotKind.allCases.contains(.verb))
    }
}
