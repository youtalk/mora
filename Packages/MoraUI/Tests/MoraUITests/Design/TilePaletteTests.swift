import XCTest
import MoraCore
import SwiftUI
@testable import MoraUI

final class TilePaletteTests: XCTestCase {
    func testAllKindsHaveDistinctFillColors() {
        let kinds: [TileKind] = [.consonant, .vowel, .multigrapheme]
        let fills = kinds.map { TilePalette.fill(for: $0) }
        XCTAssertEqual(Set(fills).count, kinds.count)
    }

    func testAllKindsHaveBorderAndText() {
        for kind in [TileKind.consonant, .vowel, .multigrapheme] {
            _ = TilePalette.border(for: kind)
            _ = TilePalette.text(for: kind)
        }
    }
}
