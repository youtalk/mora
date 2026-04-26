import XCTest
import ArgumentParser
@testable import SentenceValidator

final class CLITests: XCTestCase {
    /// `Bundle.module` resolves resources for the test target. Since the
    /// fixtures live under `Tests/SentenceValidatorTests/Fixtures/{valid,invalid}/`
    /// they're addressable as relative paths inside the test bundle.
    private func fixtureBundleURL(_ subdir: String) throws -> URL {
        guard
            let url = Bundle.module.url(forResource: "Fixtures", withExtension: nil)?
                .appendingPathComponent(subdir, isDirectory: true)
        else {
            XCTFail("Missing fixture bundle '\(subdir)'")
            throw NSError(domain: "Fixture", code: 0)
        }
        return url
    }

    func test_run_passesValidBundle() throws {
        let url = try fixtureBundleURL("valid")
        var cli = SentenceValidatorCLI()
        cli.bundle = url.path
        try cli.run()  // throws ExitCode(non-zero) on failure
    }

    func test_run_failsInvalidBundle() throws {
        let url = try fixtureBundleURL("invalid")
        var cli = SentenceValidatorCLI()
        cli.bundle = url.path

        do {
            try cli.run()
            XCTFail("expected validation to fail")
        } catch let exit as ExitCode {
            XCTAssertEqual(exit.rawValue, 1, "expected exit code 1, got \(exit.rawValue)")
        }
    }

    // Fix #4: A non-existent bundle path should exit with code 2 (configuration
    // error), not silently PASS with zero cells examined.
    func test_run_exitCode2ForMissingBundlePath() throws {
        var cli = SentenceValidatorCLI()
        cli.bundle = "/this/path/does/not/exist/at/all"

        do {
            try cli.run()
            XCTFail("expected exit code 2 for missing bundle path")
        } catch let exit as ExitCode {
            XCTAssertEqual(exit.rawValue, 2, "expected exit code 2 (config error), got \(exit.rawValue)")
        }
    }

    // Fix #1: A fixture whose payload `interest` disagrees with the filename
    // should surface a `.payloadFilenameMismatch` violation and exit with code 1.
    func test_run_failsOnPayloadFilenameMismatch() throws {
        let url = try fixtureBundleURL("mismatched")
        var cli = SentenceValidatorCLI()
        cli.bundle = url.path

        do {
            try cli.run()
            XCTFail("expected validation to fail due to payload-filename mismatch")
        } catch let exit as ExitCode {
            XCTAssertEqual(exit.rawValue, 1, "expected exit code 1 for mismatch violation, got \(exit.rawValue)")
        }
    }
}
