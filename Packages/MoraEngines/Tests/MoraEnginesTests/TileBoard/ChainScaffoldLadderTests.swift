import XCTest
import MoraCore
@testable import MoraEngines

final class ChainScaffoldLadderTests: XCTestCase {
    private func g(_ s: String) -> Grapheme { Grapheme(letters: s) }

    func testFirstMissIsBounceBack() {
        let step = ChainScaffoldLadder.next(missCount: 1, correct: g("sh"), distractor: g("ch"))
        XCTAssertEqual(step, .bounceBack)
    }

    func testSecondMissIsTTSHint() {
        let step = ChainScaffoldLadder.next(missCount: 2, correct: g("sh"), distractor: g("ch"))
        XCTAssertEqual(step, .ttsHint)
    }

    func testThirdMissReducesPool() {
        let step = ChainScaffoldLadder.next(missCount: 3, correct: g("sh"), distractor: g("ch"))
        XCTAssertEqual(step, .reducePool(correct: g("sh"), distractor: g("ch")))
    }

    func testFourthMissAutoFills() {
        let step = ChainScaffoldLadder.next(missCount: 4, correct: g("sh"), distractor: g("ch"))
        XCTAssertEqual(step, .autoFill)
    }

    func testBeyondFourthStaysAutoFill() {
        let step = ChainScaffoldLadder.next(missCount: 10, correct: g("sh"), distractor: g("ch"))
        XCTAssertEqual(step, .autoFill)
    }
}
