import XCTest
@testable import PrismKit

final class SpacingTokenValidatorTests: XCTestCase {
    private let tokens: [CGFloat] = [4, 8, 12, 16, 24, 32, 40, 48]

    func testExactTokenIsValid() {
        let result = SpacingTokenValidator.validate(8, tokens: tokens)
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.nearestToken, 8)
        XCTAssertEqual(result.difference, 0)
    }

    func testInvalidValueReportsNearestToken() {
        let result = SpacingTokenValidator.validate(13, tokens: tokens)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.nearestToken, 12)
        XCTAssertEqual(result.difference, 1)
    }

    func testValueRoundsBeforeComparison() {
        let result = SpacingTokenValidator.validate(12.4, tokens: tokens)
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.nearestToken, 12)
    }

    func testValueRoundingAwayFromToken() {
        let result = SpacingTokenValidator.validate(12.6, tokens: tokens)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.nearestToken, 12)
        XCTAssertEqual(result.difference, 1)
    }

    func testTieBreaksTowardFirstListedToken() {
        let result = SpacingTokenValidator.validate(6, tokens: tokens)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.nearestToken, 4)
        XCTAssertEqual(result.difference, 2)
    }

    func testEmptyTokenListIsInvalidWithNoNearest() {
        let result = SpacingTokenValidator.validate(8, tokens: [])
        XCTAssertFalse(result.isValid)
        XCTAssertNil(result.nearestToken)
        XCTAssertNil(result.difference)
    }

    func testNegativeValue() {
        let result = SpacingTokenValidator.validate(-2, tokens: tokens)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.nearestToken, 4)
        XCTAssertEqual(result.difference, -6)
    }

    func testZeroValue() {
        let result = SpacingTokenValidator.validate(0, tokens: tokens)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.nearestToken, 4)
        XCTAssertEqual(result.difference, -4)
    }

    func testSingleToken() {
        let result = SpacingTokenValidator.validate(100, tokens: [8])
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.nearestToken, 8)
        XCTAssertEqual(result.difference, 92)
    }
}
