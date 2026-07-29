import XCTest
@testable import PrismKit

final class MeasurementSelectionTests: XCTestCase {
    func testSelectReplacesSelection() {
        var selection = MeasurementSelection()
        XCTAssertTrue(selection.isEmpty)

        selection.select("a")
        XCTAssertEqual(selection.selectedIDs, ["a"])

        selection.select("b")
        XCTAssertEqual(selection.selectedIDs, ["b"], "Plain select replaces, like a plain click in Figma")
    }

    func testToggleAddsPreservingOrder() {
        var selection = MeasurementSelection()
        selection.select("a")
        selection.toggle("b")
        selection.toggle("c")
        XCTAssertEqual(selection.selectedIDs, ["a", "b", "c"])
        XCTAssertEqual(selection.count, 3)
        XCTAssertEqual(selection.primaryID, "a")
    }

    func testToggleRemovesWhenAlreadySelected() {
        var selection = MeasurementSelection()
        selection.select("a")
        selection.toggle("b")
        selection.toggle("a")
        XCTAssertEqual(selection.selectedIDs, ["b"])
        XCTAssertEqual(selection.primaryID, "b")
    }

    func testToggleOnEmptySelects() {
        var selection = MeasurementSelection()
        selection.toggle("a")
        XCTAssertEqual(selection.selectedIDs, ["a"])
    }

    func testClear() {
        var selection = MeasurementSelection()
        selection.select("a")
        selection.toggle("b")
        selection.clear()
        XCTAssertTrue(selection.isEmpty)
    }

    func testContains() {
        var selection = MeasurementSelection()
        selection.select("a")
        selection.toggle("b")
        XCTAssertTrue(selection.contains("a"))
        XCTAssertTrue(selection.contains("b"))
        XCTAssertFalse(selection.contains("c"))
    }
}
