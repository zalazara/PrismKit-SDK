import XCTest
@testable import PrismKit

final class LabelLayoutSolverTests: XCTestCase {
    func testEmptyInput() {
        XCTAssertTrue(LabelLayoutSolver.resolve([]).isEmpty)
    }

    func testNonOverlappingLabelsKeepPreferredPositions() {
        let candidates = [
            LabelCandidate(id: "a", rect: CGRect(x: 0, y: 0, width: 40, height: 13)),
            LabelCandidate(id: "b", rect: CGRect(x: 100, y: 0, width: 40, height: 13)),
            LabelCandidate(id: "c", rect: CGRect(x: 0, y: 50, width: 40, height: 13)),
        ]
        let positions = LabelLayoutSolver.resolve(candidates)
        XCTAssertEqual(positions["a"], CGPoint(x: 20, y: 6.5))
        XCTAssertEqual(positions["b"], CGPoint(x: 120, y: 6.5))
        XCTAssertEqual(positions["c"], CGPoint(x: 20, y: 56.5))
    }

    func testIdenticalRectsStackBelow() {
        let rect = CGRect(x: 0, y: 0, width: 40, height: 13)
        let positions = LabelLayoutSolver.resolve([
            LabelCandidate(id: "a", rect: rect),
            LabelCandidate(id: "b", rect: rect),
        ])
        XCTAssertEqual(positions["a"], CGPoint(x: 20, y: 6.5))
        XCTAssertEqual(positions["b"], CGPoint(x: 20, y: 21.5), "Pushed below the first plus 2pt spacing")
    }

    func testUpperLabelKeepsPositionRegardlessOfInputOrder() {
        let upper = LabelCandidate(id: "upper", rect: CGRect(x: 0, y: 0, width: 40, height: 13))
        let lower = LabelCandidate(id: "lower", rect: CGRect(x: 0, y: 5, width: 40, height: 13))
        let positions = LabelLayoutSolver.resolve([lower, upper])
        XCTAssertEqual(positions["upper"], CGPoint(x: 20, y: 6.5))
        XCTAssertEqual(positions["lower"]?.y, 21.5)
    }

    func testResolvedLayoutHasNoOverlaps() {
        // A cluster like the chips: several labels fighting for the same spot.
        let candidates = (0..<6).map { index in
            LabelCandidate(
                id: "label\(index)",
                rect: CGRect(x: CGFloat(index) * 8, y: CGFloat(index) * 3, width: 60, height: 13)
            )
        }
        let positions = LabelLayoutSolver.resolve(candidates)
        XCTAssertEqual(positions.count, 6)

        let resolvedRects = candidates.map { candidate in
            let center = positions[candidate.id]!
            return CGRect(
                x: center.x - candidate.rect.width / 2,
                y: center.y - candidate.rect.height / 2,
                width: candidate.rect.width,
                height: candidate.rect.height
            )
        }
        for i in resolvedRects.indices {
            for j in resolvedRects.indices where i < j {
                let intersection = resolvedRects[i].intersection(resolvedRects[j])
                XCTAssertLessThanOrEqual(
                    intersection.width * intersection.height, 0,
                    "Labels \(i) and \(j) still overlap after resolution"
                )
            }
        }
    }

    func testHorizontalPositionIsNeverChanged() {
        let rect = CGRect(x: 10, y: 0, width: 40, height: 13)
        let positions = LabelLayoutSolver.resolve([
            LabelCandidate(id: "a", rect: rect),
            LabelCandidate(id: "b", rect: rect.offsetBy(dx: 5, dy: 2)),
        ])
        XCTAssertEqual(positions["a"]?.x, 30)
        XCTAssertEqual(positions["b"]?.x, 35)
    }
}
