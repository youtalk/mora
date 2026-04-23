import XCTest
@testable import Bench

final class SpeechAceClientTests: XCTestCase {

    func testParsesOverallScoreFromSuccessPayload() throws {
        let json = #"""
        {
          "status": "success",
          "text_score": { "text": "ship", "quality_score": 82.5 }
        }
        """#.data(using: .utf8)!

        let result = SpeechAceClient.parse(responseData: json)
        XCTAssertEqual(result.score ?? 0, 82.5, accuracy: 0.001)
        XCTAssertNotNil(result.rawJSON)
    }

    func testReturnsNilScoreForErrorPayload() throws {
        let json = #"""
        {"status": "error", "message": "quota exceeded"}
        """#.data(using: .utf8)!
        let result = SpeechAceClient.parse(responseData: json)
        XCTAssertNil(result.score)
    }

    func testBuildsMultipartRequestWithAudioAndText() throws {
        let client = SpeechAceClient(apiKey: "abc", session: URLSession.shared)
        let audio = Data([0x01, 0x02])
        let req = client.buildRequest(audio: audio, text: "ship")
        XCTAssertEqual(req.url?.scheme, "https")
        XCTAssertTrue(req.url?.host?.contains("speechace") ?? false)
        XCTAssertNotNil(req.httpBody)
        XCTAssertTrue(req.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") ?? false)
    }
}
