import XCTest
@testable import PrismKit

final class MeasurementGroupTests: XCTestCase {
    func testGroupingPreservesFirstSeenOrder() {
        let measurements = [
            ResolvedMeasurement(group: "card", role: .container, frame: .zero),
            ResolvedMeasurement(group: "button", role: .container, frame: .zero),
            ResolvedMeasurement(group: "card", role: .content, frame: .zero),
        ]
        let groups = MeasurementGroup.groups(from: measurements)
        XCTAssertEqual(groups.map(\.name), ["card", "button"])
        XCTAssertEqual(groups[0].measurements.count, 2)
        XCTAssertEqual(groups[1].measurements.count, 1)
    }

    func testContentPaddingFromContainerAndContent() {
        let measurements = [
            ResolvedMeasurement(group: "button", role: .container, frame: CGRect(x: 0, y: 0, width: 120, height: 44)),
            ResolvedMeasurement(group: "button", role: .content, frame: CGRect(x: 16, y: 12, width: 88, height: 20)),
        ]
        let group = MeasurementGroup.groups(from: measurements)[0]
        XCTAssertEqual(group.contentPadding, InternalPadding(top: 12, leading: 16, bottom: 12, trailing: 16))
    }

    func testContentPaddingUsesUnionOfContentFrames() {
        let measurements = [
            ResolvedMeasurement(group: "row", role: .container, frame: CGRect(x: 0, y: 0, width: 200, height: 60)),
            ResolvedMeasurement(group: "row", role: .content, frame: CGRect(x: 16, y: 10, width: 40, height: 40)),
            ResolvedMeasurement(group: "row", role: .content, frame: CGRect(x: 100, y: 20, width: 84, height: 20)),
        ]
        let group = MeasurementGroup.groups(from: measurements)[0]
        XCTAssertEqual(group.contentUnionFrame, CGRect(x: 16, y: 10, width: 168, height: 40))
        XCTAssertEqual(group.contentPadding, InternalPadding(top: 10, leading: 16, bottom: 10, trailing: 16))
    }

    func testNoPaddingWithoutContainer() {
        let measurements = [
            ResolvedMeasurement(group: "orphan", role: .content, frame: CGRect(x: 0, y: 0, width: 10, height: 10)),
        ]
        let group = MeasurementGroup.groups(from: measurements)[0]
        XCTAssertNil(group.contentPadding)
    }

    func testNoPaddingWithoutContent() {
        let measurements = [
            ResolvedMeasurement(group: "empty", role: .container, frame: CGRect(x: 0, y: 0, width: 10, height: 10)),
        ]
        let group = MeasurementGroup.groups(from: measurements)[0]
        XCTAssertNil(group.contentPadding)
        XCTAssertNil(group.contentUnionFrame)
    }

    func testNonContentRolesDoNotAffectPadding() {
        let measurements = [
            ResolvedMeasurement(group: "row", role: .container, frame: CGRect(x: 0, y: 0, width: 100, height: 100)),
            ResolvedMeasurement(group: "row", role: .icon, frame: CGRect(x: 1, y: 1, width: 5, height: 5)),
            ResolvedMeasurement(group: "row", role: .content, frame: CGRect(x: 20, y: 20, width: 60, height: 60)),
        ]
        let group = MeasurementGroup.groups(from: measurements)[0]
        XCTAssertEqual(group.contentPadding, InternalPadding(top: 20, leading: 20, bottom: 20, trailing: 20))
    }

    func testMeasurementIdentifiers() {
        let measurement = ResolvedMeasurement(group: "primaryButton", role: .content, frame: .zero)
        XCTAssertEqual(measurement.id, "primaryButton#content")
        let custom = ResolvedMeasurement(group: "badge", role: .custom("dot"), frame: .zero)
        XCTAssertEqual(custom.id, "badge#dot")
    }
}
