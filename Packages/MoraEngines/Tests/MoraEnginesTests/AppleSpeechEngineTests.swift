#if canImport(Speech)
    import XCTest

    @testable import MoraEngines

    final class AppleSpeechEngineTests: XCTestCase {
        /// On a Mac host the CI runs, `SFSpeechRecognizer(locale:)` may return
        /// nil or `supportsOnDeviceRecognition == false`. The initializer is
        /// expected to throw (`.notSupportedOnDevice` or `.recognizerUnavailable`)
        /// in that case. This is a smoke check that the initializer doesn't crash
        /// — correctness on a device is covered by spec §15.1 device smoke.
        func test_initializer_throwsWhenOnDeviceUnavailable() throws {
            _ = try? AppleSpeechEngine(localeIdentifier: "zz-ZZ")
        }
    }
#endif
