#if canImport(Speech)
import XCTest

@testable import MoraEngines

final class AppleSpeechEngineTests: XCTestCase {
    /// An unsupported locale must make the initializer throw one of the
    /// pre-on-device errors. Use XCTAssertThrowsError so a regression
    /// where the initializer silently succeeds actually fails the suite
    /// (the previous `_ = try?` form passed either way).
    func test_initializer_throwsForUnsupportedLocale() {
        XCTAssertThrowsError(
            try AppleSpeechEngine(localeIdentifier: "zz-ZZ")
        ) { error in
            guard let typed = error as? AppleSpeechEngineError else {
                XCTFail("unexpected error: \(error)")
                return
            }
            XCTAssertTrue(
                typed == .recognizerUnavailable
                    || typed == .notSupportedOnDevice,
                "unexpected AppleSpeechEngineError: \(typed)"
            )
        }
    }
}
#endif
