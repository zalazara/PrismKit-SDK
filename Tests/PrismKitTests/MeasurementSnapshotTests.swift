import XCTest
@testable import PrismKit

final class MeasurementSnapshotTests: XCTestCase {
    private func makeSnapshot() -> MeasurementSnapshot {
        MeasurementSnapshot(
            appName: "ExampleApp",
            bundleID: "com.example.app",
            screenSize: CGSize(width: 393, height: 852),
            screenScale: 3,
            scopeFrame: CGRect(x: 0, y: 59, width: 393, height: 710),
            safeAreaInsets: StreamInsets(top: 59, leading: 0, bottom: 34, trailing: 0),
            measurements: [
                ResolvedMeasurement(
                    group: "primaryButton",
                    role: .container,
                    frame: CGRect(x: 16, y: 100, width: 158, height: 43),
                    metadata: ["variant": "filled"]
                ),
                ResolvedMeasurement(
                    group: "badge",
                    role: .custom("dot"),
                    frame: CGRect(x: 200, y: 100, width: 8, height: 8)
                ),
            ]
        )
    }

    func testCodableRoundTrip() throws {
        let snapshot = makeSnapshot()
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(MeasurementSnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)
    }

    func testRoundTripPreservesCustomRoleAndMetadata() throws {
        let data = try JSONEncoder().encode(makeSnapshot())
        let decoded = try JSONDecoder().decode(MeasurementSnapshot.self, from: data)
        XCTAssertEqual(decoded.measurements[1].role, .custom("dot"))
        XCTAssertEqual(decoded.measurements[0].metadata["variant"], "filled")
    }

    func testGlobalFrameOffsetsByScopeOrigin() {
        let snapshot = makeSnapshot()
        let global = snapshot.globalFrame(for: snapshot.measurements[0])
        XCTAssertEqual(global, CGRect(x: 16, y: 159, width: 158, height: 43))
    }

    func testAutomaticMeasurementsDeriveFromAccessibilityTree() {
        var snapshot = makeSnapshot()
        snapshot.accessibilityElements = [
            AccessibilityElementInfo(
                label: "Trail Sneakers, $129",
                traits: ["button"],
                frame: CGRect(x: 16, y: 259, width: 361, height: 72)
            ),
            AccessibilityElementInfo(
                identifier: "search-field",
                traits: ["searchField"],
                frame: CGRect(x: 16, y: 159, width: 361, height: 40)
            ),
        ]

        let auto = snapshot.automaticMeasurements
        XCTAssertEqual(auto.count, 2)

        // Screen coordinates convert to scope-local (scope starts at y 59),
        // so globalFrame round-trips back to the accessibility frame.
        XCTAssertEqual(auto[0].frame, CGRect(x: 16, y: 200, width: 361, height: 72))
        XCTAssertEqual(snapshot.globalFrame(for: auto[0]), snapshot.accessibilityElements[0].frame)

        // Named by badge number plus identifier or label.
        XCTAssertEqual(auto[0].group, "1 · Trail Sneakers, $129")
        XCTAssertEqual(auto[1].group, "2 · search-field")
        XCTAssertEqual(auto[1].metadata["identifier"], "search-field")
        XCTAssertEqual(auto[0].metadata["traits"], "button")

        // Merged list keeps instrumented measurements first.
        XCTAssertEqual(snapshot.allMeasurements.count, 4)
        XCTAssertEqual(snapshot.allMeasurements[0].group, "primaryButton")
    }

    func testAutomaticMeasurementsEmptyWithoutAccessibility() {
        let snapshot = makeSnapshot()
        XCTAssertTrue(snapshot.automaticMeasurements.isEmpty)
        XCTAssertEqual(snapshot.allMeasurements, snapshot.measurements)
    }

    func testAccessibilityTreeRoundTrip() throws {
        var snapshot = makeSnapshot()
        snapshot.accessibilityElements = [
            AccessibilityElementInfo(
                label: "Trail Sneakers, $129",
                traits: ["button"],
                frame: CGRect(x: 16, y: 259, width: 361, height: 72)
            )
        ]
        snapshot.accessibilityTree = [
            AccessibilityTreeNode(
                className: "UIWindow",
                frame: CGRect(x: 0, y: 0, width: 393, height: 852),
                children: [
                    AccessibilityTreeNode(
                        className: "UIScrollView",
                        frame: CGRect(x: 0, y: 59, width: 393, height: 710),
                        children: [
                            AccessibilityTreeNode(
                                className: "UIAccessibilityElement",
                                frame: CGRect(x: 16, y: 259, width: 361, height: 72),
                                elementIndex: 0
                            )
                        ]
                    )
                ]
            )
        ]

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(MeasurementSnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.accessibilityTree?.first?.children.first?.children.first?.elementIndex, 0)
    }

    func testTreeMeasurementsExposeVisualLeavesOnly() {
        var snapshot = makeSnapshot()
        snapshot.accessibilityElements = [
            AccessibilityElementInfo(
                label: "Trail Sneakers, $129",
                traits: ["button"],
                frame: CGRect(x: 16, y: 259, width: 361, height: 72)
            )
        ]
        snapshot.accessibilityTree = [
            AccessibilityTreeNode(
                className: "PlatformGroupContainer",
                frame: CGRect(x: 0, y: 59, width: 393, height: 710),
                children: [
                    AccessibilityTreeNode(
                        className: "UIAccessibilityElement",
                        frame: CGRect(x: 16, y: 259, width: 361, height: 72),
                        elementIndex: 0,
                        children: [
                            AccessibilityTreeNode(
                                className: "CGDrawingView",
                                frame: CGRect(x: 80, y: 270, width: 120, height: 20)
                            )
                        ]
                    )
                ]
            )
        ]

        let visual = snapshot.treeMeasurements
        // Only the drawing leaf — never the container, never the element.
        XCTAssertEqual(visual.count, 1)
        XCTAssertEqual(visual[0].id, "CGDrawingView · 0.0.0#view")
        // Frames convert from screen to scope-local coordinates.
        XCTAssertEqual(visual[0].frame, CGRect(x: 80, y: 211, width: 120, height: 20))
        XCTAssertTrue(snapshot.allMeasurements.contains { $0.id == visual[0].id })
    }

    func testDecodingSnapshotWithoutAccessibilityTreeSucceeds() throws {
        // Sessions saved before the hierarchy field existed must keep loading.
        var old = makeSnapshot()
        old.accessibilityTree = nil
        let data = try JSONEncoder().encode(old)
        XCTAssertFalse(String(data: data, encoding: .utf8)!.contains("accessibilityTree"))
        let decoded = try JSONDecoder().decode(MeasurementSnapshot.self, from: data)
        XCTAssertNil(decoded.accessibilityTree)
    }
}
