import XCTest
@testable import PrismKit

final class ExternalSpacingTests: XCTestCase {
    func testSideBySideFrames() {
        let spacing = ExternalSpacing.between(
            CGRect(x: 0, y: 0, width: 50, height: 50),
            CGRect(x: 70, y: 10, width: 50, height: 50)
        )
        XCTAssertEqual(spacing.horizontal, 20)
        XCTAssertEqual(spacing.vertical, 0, "Frames overlap vertically, so vertical spacing is zero")
    }

    func testVerticallyStackedFrames() {
        let spacing = ExternalSpacing.between(
            CGRect(x: 0, y: 0, width: 50, height: 50),
            CGRect(x: 10, y: 82, width: 50, height: 50)
        )
        XCTAssertEqual(spacing.horizontal, 0)
        XCTAssertEqual(spacing.vertical, 32)
    }

    func testOverlappingFrames() {
        let spacing = ExternalSpacing.between(
            CGRect(x: 0, y: 0, width: 50, height: 50),
            CGRect(x: 25, y: 25, width: 50, height: 50)
        )
        XCTAssertEqual(spacing, ExternalSpacing(horizontal: 0, vertical: 0))
    }

    func testDiagonalFramesHaveBothGaps() {
        let spacing = ExternalSpacing.between(
            CGRect(x: 0, y: 0, width: 50, height: 50),
            CGRect(x: 62, y: 74, width: 50, height: 50)
        )
        XCTAssertEqual(spacing.horizontal, 12)
        XCTAssertEqual(spacing.vertical, 24)
    }

    func testTouchingEdgesHaveZeroGap() {
        let spacing = ExternalSpacing.between(
            CGRect(x: 0, y: 0, width: 50, height: 50),
            CGRect(x: 50, y: 0, width: 50, height: 50)
        )
        XCTAssertEqual(spacing, ExternalSpacing(horizontal: 0, vertical: 0))
    }

    func testOrderIndependence() {
        let a = CGRect(x: 0, y: 0, width: 50, height: 50)
        let b = CGRect(x: 70, y: 90, width: 30, height: 30)
        XCTAssertEqual(ExternalSpacing.between(a, b), ExternalSpacing.between(b, a))
    }

    func testZeroSizedFrame() {
        let spacing = ExternalSpacing.between(
            CGRect(x: 0, y: 0, width: 0, height: 0),
            CGRect(x: 10, y: 0, width: 20, height: 20)
        )
        XCTAssertEqual(spacing.horizontal, 10)
        XCTAssertEqual(spacing.vertical, 0)
    }

    func testRounding() {
        let spacing = ExternalSpacing(horizontal: 11.6, vertical: 4.4).rounded()
        XCTAssertEqual(spacing, ExternalSpacing(horizontal: 12, vertical: 4))
    }
}
