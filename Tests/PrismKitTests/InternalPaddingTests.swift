import XCTest
@testable import PrismKit

final class InternalPaddingTests: XCTestCase {
    func testUniformPadding() {
        let padding = InternalPadding.between(
            container: CGRect(x: 0, y: 0, width: 100, height: 100),
            content: CGRect(x: 10, y: 10, width: 80, height: 80)
        )
        XCTAssertEqual(padding, InternalPadding(top: 10, leading: 10, bottom: 10, trailing: 10))
    }

    func testAsymmetricPadding() {
        let padding = InternalPadding.between(
            container: CGRect(x: 0, y: 0, width: 100, height: 50),
            content: CGRect(x: 12, y: 8, width: 60, height: 30)
        )
        XCTAssertEqual(padding.top, 8)
        XCTAssertEqual(padding.leading, 12)
        XCTAssertEqual(padding.bottom, 12)
        XCTAssertEqual(padding.trailing, 28)
    }

    func testOffsetContainerOrigin() {
        let padding = InternalPadding.between(
            container: CGRect(x: 50, y: 100, width: 200, height: 60),
            content: CGRect(x: 66, y: 112, width: 168, height: 36)
        )
        XCTAssertEqual(padding, InternalPadding(top: 12, leading: 16, bottom: 12, trailing: 16))
    }

    func testContentOutsideContainerIsNegative() {
        let padding = InternalPadding.between(
            container: CGRect(x: 0, y: 0, width: 100, height: 100),
            content: CGRect(x: -5, y: 10, width: 120, height: 80)
        )
        XCTAssertEqual(padding.leading, -5)
        XCTAssertEqual(padding.trailing, -15)
        XCTAssertEqual(padding.top, 10)
        XCTAssertEqual(padding.bottom, 10)
    }

    func testZeroSizedContainer() {
        let padding = InternalPadding.between(
            container: .zero,
            content: CGRect(x: 4, y: 4, width: 8, height: 8)
        )
        XCTAssertEqual(padding, InternalPadding(top: 4, leading: 4, bottom: -12, trailing: -12))
    }

    func testRounding() {
        let padding = InternalPadding(top: 9.6, leading: 10.4, bottom: 10.5, trailing: -1.6).rounded()
        XCTAssertEqual(padding.top, 10)
        XCTAssertEqual(padding.leading, 10)
        XCTAssertEqual(padding.bottom, 11)
        XCTAssertEqual(padding.trailing, -2)
    }
}
