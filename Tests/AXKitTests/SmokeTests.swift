import XCTest

@testable import AXKit

/// Placeholder so the package resolves; real hermetic tests land next.
final class SmokeTests: XCTestCase {
    func testRefusalPrecedenceIsComplete() {
        // SPEC §8.3: every RefusalCode must appear exactly once in the
        // precedence list, and `first(_:)` must agree with that ordering.
        XCTAssertEqual(Set(RefusalCode.precedence), Set(RefusalCode.allCases))
        XCTAssertEqual(RefusalCode.precedence.count, RefusalCode.allCases.count)
        XCTAssertEqual(RefusalCode.first([.ambiguousName, .budgetExhausted]), .budgetExhausted)
        XCTAssertNil(RefusalCode.first([]))
    }
}