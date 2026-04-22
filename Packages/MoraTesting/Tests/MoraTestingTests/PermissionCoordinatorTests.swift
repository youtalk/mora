import MoraEngines
import XCTest

@testable import MoraTesting

@MainActor
final class PermissionCoordinatorTests: XCTestCase {
    func test_notDetermined_startsAsNotDetermined() {
        let source = FakePermissionSource(
            mic: .notDetermined,
            speech: .notDetermined
        )
        let coord = PermissionCoordinator(source: source)
        XCTAssertEqual(coord.current(), .notDetermined)
    }

    func test_bothGranted_isAllGranted() {
        let source = FakePermissionSource(mic: .granted, speech: .granted)
        let coord = PermissionCoordinator(source: source)
        XCTAssertEqual(coord.current(), .allGranted)
    }

    func test_micDenied_isPartial() {
        let source = FakePermissionSource(mic: .denied, speech: .granted)
        let coord = PermissionCoordinator(source: source)
        XCTAssertEqual(coord.current(), .partial(micDenied: true, speechDenied: false))
    }

    func test_request_flipsNotDeterminedToGranted() async {
        let source = FakePermissionSource(mic: .notDetermined, speech: .notDetermined)
        source.nextMicResult = .granted
        source.nextSpeechResult = .granted
        let coord = PermissionCoordinator(source: source)
        let result = await coord.request()
        XCTAssertEqual(result, .allGranted)
    }
}
