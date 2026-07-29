import XCTest
@testable import PrismKit

final class AlignmentCheckerTests: XCTestCase {
    func testAlignedLeadingEdgesAreGrouped() {
        let report = AlignmentChecker.report(measurements: [
            ResolvedMeasurement(group: "a", role: .container, frame: CGRect(x: 16, y: 0, width: 100, height: 40)),
            ResolvedMeasurement(group: "b", role: .container, frame: CGRect(x: 16, y: 60, width: 80, height: 40)),
        ])
        let leading = report.alignedEdges.first { $0.edge == "leading" && $0.position == 16 }
        XCTAssertEqual(leading?.measurementIDs, ["a#container", "b#container"])
    }

    func testNearMissAlignmentIsReported() {
        let report = AlignmentChecker.report(
            measurements: [
                ResolvedMeasurement(group: "a", role: .container, frame: CGRect(x: 16, y: 0, width: 100, height: 40)),
                ResolvedMeasurement(group: "b", role: .container, frame: CGRect(x: 18, y: 60, width: 80, height: 40)),
            ],
            tolerance: 2
        )
        let nearMiss = report.issues.first { $0.kind == .nearMissAlignment }
        XCTAssertNotNil(nearMiss)
        XCTAssertEqual(nearMiss?.value, 2)
        XCTAssertEqual(nearMiss?.suggestion, 16)
    }

    func testExactAlignmentIsNotANearMiss() {
        let report = AlignmentChecker.report(measurements: [
            ResolvedMeasurement(group: "a", role: .container, frame: CGRect(x: 16, y: 0, width: 100, height: 40)),
            ResolvedMeasurement(group: "b", role: .container, frame: CGRect(x: 16, y: 60, width: 100, height: 40)),
        ])
        XCTAssertFalse(report.issues.contains { $0.kind == .nearMissAlignment && $0.message.contains("leading") })
    }

    func testInvalidPaddingIsReported() {
        let report = AlignmentChecker.report(measurements: [
            ResolvedMeasurement(group: "button", role: .container, frame: CGRect(x: 0, y: 0, width: 120, height: 50)),
            ResolvedMeasurement(group: "button", role: .content, frame: CGRect(x: 13, y: 13, width: 94, height: 24)),
        ])
        let paddingIssue = report.issues.first { $0.kind == .invalidPadding }
        XCTAssertNotNil(paddingIssue)
        XCTAssertEqual(paddingIssue?.value, 13)
        XCTAssertEqual(paddingIssue?.suggestion, 12)
    }

    func testInvalidGapBetweenNeighborsIsReported() {
        let report = AlignmentChecker.report(measurements: [
            ResolvedMeasurement(group: "chipA", role: .container, frame: CGRect(x: 0, y: 0, width: 60, height: 26)),
            ResolvedMeasurement(group: "chipB", role: .container, frame: CGRect(x: 74, y: 0, width: 60, height: 26)),
        ])
        let gapIssue = report.issues.first { $0.kind == .invalidSpacing }
        XCTAssertNotNil(gapIssue)
        XCTAssertEqual(gapIssue?.value, 14)
        // 14 ties between tokens 12 and 16; the earlier-listed token wins.
        XCTAssertEqual(gapIssue?.suggestion, 12)
    }

    func testTokenIssuesSuppressedWhenValidationDisabled() {
        var configuration = MeasureConfiguration()
        configuration.validatesTokens = false
        let report = AlignmentChecker.report(
            measurements: [
                ResolvedMeasurement(group: "button", role: .container, frame: CGRect(x: 0, y: 0, width: 120, height: 50)),
                ResolvedMeasurement(group: "button", role: .content, frame: CGRect(x: 13, y: 13, width: 94, height: 24)),
            ],
            configuration: configuration
        )
        XCTAssertFalse(report.issues.contains { $0.kind == .invalidPadding })
    }
}
