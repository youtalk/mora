import MoraCore
import MoraEngines
import XCTest

@testable import MoraTesting

final class FakeSpeechEngineTests: XCTestCase {
    func test_yieldingFinals_producesFinalEvents() async throws {
        let engine = FakeSpeechEngine.yielding(finals: [
            ASRResult(transcript: "ship", confidence: 0.9),
            ASRResult(transcript: "shop", confidence: 0.85),
        ])
        var events: [SpeechEvent] = []
        for try await event in engine.listen() {
            events.append(event)
        }
        XCTAssertEqual(events.count, 1)
        if case .final(let asr) = events.first {
            XCTAssertEqual(asr.transcript, "ship")
        } else {
            XCTFail("Expected first event to be .final")
        }
    }

    func test_yieldingEvents_producesPartialsThenFinal() async throws {
        let engine = FakeSpeechEngine.yielding([
            .started,
            .partial("sh"),
            .partial("shi"),
            .final(ASRResult(transcript: "ship", confidence: 0.92)),
        ])
        var events: [SpeechEvent] = []
        for try await event in engine.listen() {
            events.append(event)
        }
        XCTAssertEqual(events.count, 4)
    }

    func test_scriptExhausted_throws() async {
        let engine = FakeSpeechEngine(scripts: [])
        do {
            for try await _ in engine.listen() {
                XCTFail("Should have thrown before yielding")
            }
            XCTFail("Should have thrown")
        } catch {
            XCTAssertEqual(error as? FakeSpeechEngineError, .scriptExhausted)
        }
    }
}
