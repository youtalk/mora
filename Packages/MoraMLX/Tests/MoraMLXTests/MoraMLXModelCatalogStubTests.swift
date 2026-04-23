import XCTest

@testable import MoraMLX

final class MoraMLXModelCatalogStubTests: XCTestCase {
    func testStubAlwaysThrowsModelNotBundled() {
        do {
            _ = try MoraMLXModelCatalog.loadPhonemeEvaluator()
            XCTFail("expected throw")
        } catch MoraMLXError.modelNotBundled {
            // ok
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
