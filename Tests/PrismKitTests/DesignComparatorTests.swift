import CoreGraphics
import XCTest
@testable import PrismKit

/// The comparator's value rests entirely on the pairing being right: a wrong
/// pair produces a confident, well-formatted, completely invented defect,
/// which is worse than reporting nothing. These tests exercise each pairing
/// pass and the ways they can go wrong.
final class DesignComparatorTests: XCTestCase {
    // MARK: - Fixtures

    private func snapshot(
        screen: CGSize = CGSize(width: 400, height: 800),
        measurements: [ResolvedMeasurement] = [],
        elements: [AccessibilityElementInfo] = []
    ) -> MeasurementSnapshot {
        MeasurementSnapshot(
            appName: "Example",
            screenSize: screen,
            screenScale: 3,
            scopeFrame: CGRect(origin: .zero, size: screen),
            safeAreaInsets: StreamInsets(top: 0, leading: 0, bottom: 0, trailing: 0),
            measurements: measurements,
            accessibilityElements: elements
        )
    }

    private func element(
        label: String? = nil,
        identifier: String? = nil,
        frame: CGRect
    ) -> AccessibilityElementInfo {
        AccessibilityElementInfo(
            label: label,
            value: nil,
            hint: nil,
            identifier: identifier,
            traits: [],
            frame: frame
        )
    }

    private func node(
        id: String,
        name: String? = nil,
        match: String? = nil,
        frame: CGRect,
        text: String? = nil
    ) -> DesignNode {
        DesignNode(
            id: id,
            name: name,
            match: match,
            frame: DesignRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height),
            text: text
        )
    }

    private func spec(width: CGFloat = 400, nodes: [DesignNode]) -> DesignSpec {
        DesignSpec(frame: DesignSize(width: width, height: 800), nodes: nodes)
    }

    // MARK: - A screen that matches its design

    func testMatchingScreenProducesNoFindings() {
        let snapshot = snapshot(
            measurements: [
                ResolvedMeasurement(
                    group: "buyButton",
                    role: .container,
                    frame: CGRect(x: 24, y: 700, width: 352, height: 52)
                )
            ]
        )
        let design = spec(nodes: [
            node(id: "1", name: "buyButton", frame: CGRect(x: 24, y: 700, width: 352, height: 52))
        ])

        let diff = DesignComparator.compare(design: design, snapshot: snapshot)

        XCTAssertTrue(diff.findings.isEmpty, "A screen that matches its design must report nothing")
        XCTAssertEqual(diff.matches.first?.matchedBy, .identifier)
    }

    // MARK: - Geometry

    func testReportsPositionAndSizeDifferences() {
        let snapshot = snapshot(
            measurements: [
                ResolvedMeasurement(
                    group: "buyButton",
                    role: .container,
                    frame: CGRect(x: 24, y: 688, width: 352, height: 44)
                )
            ]
        )
        let design = spec(nodes: [
            node(id: "1", name: "buyButton", frame: CGRect(x: 24, y: 700, width: 352, height: 52))
        ])

        let diff = DesignComparator.compare(design: design, snapshot: snapshot)

        let y = diff.findings.first { $0.property == "y" }
        XCTAssertEqual(y?.kind, .positionMismatch)
        XCTAssertEqual(y?.delta, -12, "The button sits 12 pt higher than designed")
        XCTAssertEqual(y?.severity, .error, "An identifier pair is certain")

        let height = diff.findings.first { $0.property == "height" }
        XCTAssertEqual(height?.kind, .sizeMismatch)
        XCTAssertEqual(height?.delta, -8)

        XCTAssertNil(diff.findings.first { $0.property == "x" }, "x is correct and must not be reported")
    }

    func testDifferencesWithinToleranceAreNotReported() {
        let snapshot = snapshot(
            measurements: [
                ResolvedMeasurement(
                    group: "card",
                    role: .container,
                    frame: CGRect(x: 16.4, y: 100, width: 368, height: 200)
                )
            ]
        )
        let design = spec(nodes: [
            node(id: "1", name: "card", frame: CGRect(x: 16, y: 100, width: 368, height: 200))
        ])

        let diff = DesignComparator.compare(design: design, snapshot: snapshot, options: .default)

        XCTAssertTrue(diff.findings.isEmpty, "0.4 pt is below the 1 pt default tolerance")
    }

    // MARK: - Scaling

    func testDesignAtAnotherWidthIsScaledOntoTheDevice() {
        // Design drawn at 200 pt wide, device is 400 pt: everything doubles.
        let snapshot = snapshot(
            measurements: [
                ResolvedMeasurement(
                    group: "hero",
                    role: .container,
                    frame: CGRect(x: 40, y: 80, width: 320, height: 200)
                )
            ]
        )
        let design = spec(width: 200, nodes: [
            node(id: "1", name: "hero", frame: CGRect(x: 20, y: 40, width: 160, height: 100))
        ])

        let diff = DesignComparator.compare(design: design, snapshot: snapshot)

        XCTAssertEqual(diff.scale.factor, 2)
        XCTAssertTrue(diff.findings.isEmpty, "The same layout at half scale must compare clean")
    }

    // MARK: - Pairing passes

    func testPairsByAccessibilityIdentifierWhenNamesDiffer() {
        let snapshot = snapshot(
            elements: [
                element(identifier: "checkout-cta", frame: CGRect(x: 24, y: 700, width: 352, height: 52))
            ]
        )
        let design = spec(nodes: [
            node(id: "1", name: "Primary / Button", match: "checkout-cta",
                 frame: CGRect(x: 24, y: 700, width: 352, height: 52))
        ])

        let diff = DesignComparator.compare(design: design, snapshot: snapshot)

        XCTAssertEqual(diff.matches.first?.matchedBy, .identifier)
        XCTAssertTrue(diff.findings.isEmpty)
    }

    func testPairsByTextWhenThereIsNoIdentifier() {
        let snapshot = snapshot(
            elements: [
                element(label: "Comprar ahora", frame: CGRect(x: 24, y: 688, width: 352, height: 52))
            ]
        )
        let design = spec(nodes: [
            node(id: "1", frame: CGRect(x: 24, y: 700, width: 352, height: 52), text: "Comprar ahora")
        ])

        let diff = DesignComparator.compare(design: design, snapshot: snapshot)

        XCTAssertEqual(diff.matches.first?.matchedBy, .text)
        XCTAssertEqual(diff.findings.first { $0.property == "y" }?.delta, -12)
    }

    func testPairsByOverlapAsALastResortAndDowngradesSeverity() {
        let snapshot = snapshot(
            elements: [
                element(frame: CGRect(x: 24, y: 706, width: 352, height: 52))
            ]
        )
        let design = spec(nodes: [
            node(id: "1", frame: CGRect(x: 24, y: 700, width: 352, height: 52))
        ])

        let diff = DesignComparator.compare(design: design, snapshot: snapshot)

        XCTAssertEqual(diff.matches.first?.matchedBy, .overlap)
        let y = diff.findings.first { $0.property == "y" }
        XCTAssertEqual(y?.delta, 6)
        XCTAssertEqual(y?.severity, .warning, "A guessed pair must not report a certain defect")
    }

    func testDistantElementIsNotPairedByOverlap() {
        let snapshot = snapshot(
            elements: [
                element(frame: CGRect(x: 24, y: 100, width: 352, height: 52))
            ]
        )
        let design = spec(nodes: [
            node(id: "1", name: "footer", frame: CGRect(x: 24, y: 700, width: 352, height: 52))
        ])

        let diff = DesignComparator.compare(design: design, snapshot: snapshot)

        XCTAssertTrue(diff.matches.isEmpty, "Nothing overlaps, so nothing should be paired")
        XCTAssertEqual(diff.findings.first?.kind, .missingElement)
        XCTAssertNil(
            diff.findings.first?.elementID,
            "Nothing overlaps at all, so there is no near miss to point at"
        )
    }

    /// An element that moved far enough to fail the pairing threshold is
    /// still on screen. Reporting a bare "missing" would send someone looking
    /// for something they can see.
    func testMissingReportNamesTheClosestRejectedElement() {
        let snapshot = snapshot(
            elements: [
                element(frame: CGRect(x: 24, y: 720, width: 352, height: 52))
            ]
        )
        let design = spec(nodes: [
            node(id: "1", name: "footer", frame: CGRect(x: 24, y: 700, width: 352, height: 52))
        ])

        let diff = DesignComparator.compare(design: design, snapshot: snapshot)

        let missing = diff.findings.first { $0.kind == .missingElement }
        XCTAssertNotNil(missing?.elementID, "The near miss must be named")
        XCTAssertTrue(
            missing?.message.contains("moved rather than disappeared") == true,
            "The message must say it may have moved, not simply vanished"
        )
    }

    func testAnElementIsClaimedOnlyOnce() {
        // Two design nodes, one element: the identifier pair wins it and the
        // other node is reported missing rather than stealing the same element.
        let snapshot = snapshot(
            elements: [
                element(identifier: "cta", frame: CGRect(x: 24, y: 700, width: 352, height: 52))
            ]
        )
        let design = spec(nodes: [
            node(id: "1", name: "cta", frame: CGRect(x: 24, y: 700, width: 352, height: 52)),
            node(id: "2", name: "ghost", frame: CGRect(x: 24, y: 700, width: 352, height: 52)),
        ])

        let diff = DesignComparator.compare(design: design, snapshot: snapshot)

        XCTAssertEqual(diff.matches.count, 1)
        XCTAssertEqual(diff.matches.first?.designNode, "cta")
        XCTAssertEqual(diff.findings.filter { $0.kind == .missingElement }.map(\.designNode), ["ghost"])
    }

    func testBestOverlapWinsRegardlessOfNodeOrder() {
        // The first-listed node overlaps weakly; the second is a near-exact
        // fit. Best-first assignment must give the element to the second.
        let snapshot = snapshot(
            elements: [
                element(frame: CGRect(x: 100, y: 100, width: 100, height: 100))
            ]
        )
        let design = spec(nodes: [
            node(id: "loose", frame: CGRect(x: 60, y: 60, width: 140, height: 140)),
            node(id: "tight", frame: CGRect(x: 100, y: 102, width: 100, height: 100)),
        ])

        let diff = DesignComparator.compare(design: design, snapshot: snapshot)

        XCTAssertEqual(diff.matches.count, 1)
        XCTAssertEqual(diff.matches.first?.designNode, "tight")
    }

    // MARK: - Text

    func testReportsWordingThatDrifted() {
        let snapshot = snapshot(
            elements: [
                element(label: "Buy", identifier: "cta", frame: CGRect(x: 24, y: 700, width: 352, height: 52))
            ]
        )
        let design = spec(nodes: [
            node(id: "1", match: "cta", frame: CGRect(x: 24, y: 700, width: 352, height: 52), text: "Buy now")
        ])

        let diff = DesignComparator.compare(design: design, snapshot: snapshot)

        let text = diff.findings.first { $0.kind == .textMismatch }
        XCTAssertEqual(text?.expectedText, "Buy now")
        XCTAssertEqual(text?.actualText, "Buy")
    }

    func testTextComparisonCanBeTurnedOffForDynamicContent() {
        let snapshot = snapshot(
            elements: [
                element(label: "$1,234.56", identifier: "total", frame: CGRect(x: 24, y: 700, width: 352, height: 52))
            ]
        )
        let design = spec(nodes: [
            node(id: "1", match: "total", frame: CGRect(x: 24, y: 700, width: 352, height: 52), text: "$0.00")
        ])

        let options = DesignComparisonOptions(comparesText: false)
        let diff = DesignComparator.compare(design: design, snapshot: snapshot, options: options)

        XCTAssertTrue(diff.findings.isEmpty, "Real data must not be reported as a defect")
    }

    // MARK: - Noise control

    func testExtraScreenElementsAreListedButNotReportedAsDefects() {
        let snapshot = snapshot(
            elements: [
                element(identifier: "cta", frame: CGRect(x: 24, y: 700, width: 352, height: 52)),
                element(label: "9:41", frame: CGRect(x: 20, y: 5, width: 40, height: 20)),
                element(label: "Back", frame: CGRect(x: 8, y: 50, width: 60, height: 30)),
            ]
        )
        let design = spec(nodes: [
            node(id: "1", match: "cta", frame: CGRect(x: 24, y: 700, width: 352, height: 52))
        ])

        let diff = DesignComparator.compare(design: design, snapshot: snapshot)

        XCTAssertTrue(diff.findings.isEmpty, "A partial spec must not turn the rest of the screen into defects")
        XCTAssertEqual(diff.unmatchedScreenElements.count, 2)
    }

    // MARK: - Report shape

    func testErrorsAreOrderedBeforeWarnings() {
        let snapshot = snapshot(
            elements: [
                element(identifier: "cta", frame: CGRect(x: 24, y: 703, width: 352, height: 52)),
                element(frame: CGRect(x: 24, y: 290, width: 352, height: 52)),
            ]
        )
        let design = spec(nodes: [
            node(id: "1", match: "cta", frame: CGRect(x: 24, y: 700, width: 352, height: 52)),
            node(id: "2", frame: CGRect(x: 24, y: 280, width: 352, height: 52)),
        ])

        let diff = DesignComparator.compare(design: design, snapshot: snapshot)

        XCTAssertEqual(diff.findings.first?.severity, .error)
        XCTAssertEqual(diff.findings.last?.severity, .warning)
    }

    func testDiffSurvivesAJSONRoundTrip() throws {
        let snapshot = snapshot(
            measurements: [
                ResolvedMeasurement(group: "cta", role: .container, frame: CGRect(x: 24, y: 688, width: 352, height: 52))
            ]
        )
        let design = DesignSpec(
            source: "figma",
            reference: "file/ABC?node-id=1:2",
            frame: DesignSize(width: 400, height: 800),
            nodes: [node(id: "1", name: "cta", frame: CGRect(x: 24, y: 700, width: 352, height: 52))]
        )

        let diff = DesignComparator.compare(design: design, snapshot: snapshot)
        let data = try JSONEncoder().encode(diff)
        let decoded = try JSONDecoder().decode(DesignDiff.self, from: data)

        XCTAssertEqual(decoded, diff)
        XCTAssertEqual(decoded.source, "figma")
    }

    func testSpecDecodesFromTheJSONAnAgentWouldWrite() throws {
        let json = """
        {
          "source": "pencil",
          "frame": { "width": 390, "height": 844 },
          "nodes": [
            {
              "id": "1:235",
              "name": "primaryButton",
              "match": "buyButton",
              "frame": { "x": 24, "y": 700, "width": 342, "height": 52 },
              "text": "Comprar ahora"
            }
          ]
        }
        """
        let spec = try JSONDecoder().decode(DesignSpec.self, from: Data(json.utf8))

        XCTAssertEqual(spec.source, "pencil")
        XCTAssertEqual(spec.frame.width, 390)
        XCTAssertEqual(spec.nodes.first?.match, "buyButton")
        XCTAssertEqual(spec.nodes.first?.frame.y, 700)
        XCTAssertNil(spec.nodes.first?.padding, "Optional fields must stay optional")
    }
}
