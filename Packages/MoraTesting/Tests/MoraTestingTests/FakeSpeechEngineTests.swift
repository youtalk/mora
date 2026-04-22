import MoraCore
import MoraEngines
import XCTest

@testable import MoraTesting

final class FakeSpeechEngineTests: XCTestCase {
    func test_listen_returnsScriptedResult() async throws {
        let engine = FakeSpeechEngine()
        engine.scriptedResults = [
            ASRResult(transcript: "ship", confidence: 0.95)
        ]
        let result = try await engine.listen()
        XCTAssertEqual(result.transcript, "ship")
    }

    func test_listen_consumesScriptedResultsInOrder() async throws {
        let engine = FakeSpeechEngine()
        engine.scriptedResults = [
            ASRResult(transcript: "first", confidence: 1),
            ASRResult(transcript: "second", confidence: 1),
        ]
        let a = try await engine.listen()
        let b = try await engine.listen()
        XCTAssertEqual(a.transcript, "first")
        XCTAssertEqual(b.transcript, "second")
    }

    func test_listen_throwsWhenEmpty() async {
        let engine = FakeSpeechEngine()
        do {
            _ = try await engine.listen()
            XCTFail("expected exhausted error")
        } catch FakeSpeechEngineError.scriptExhausted {
            // ok
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
