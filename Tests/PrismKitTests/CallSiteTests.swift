import XCTest
@testable import PrismKit

final class CallSiteTests: XCTestCase {
    /// The whole point is that the compiler fills these in from the *caller*,
    /// so the test has to be the caller.
    func testDefaultArgumentsCaptureTheCallingLine() {
        let line = #line + 1
        let site = CallSite()

        XCTAssertEqual(site.line, line)
        XCTAssertEqual(site.fileName, "CallSiteTests.swift")
        XCTAssertEqual(site.file, "PrismKitTests/CallSiteTests.swift")
        XCTAssertFalse(
            site.file.hasPrefix("/"),
            "#fileID, not #filePath: a whole path would write this machine's directory layout into any release binary that failed to strip it"
        )
    }

    /// A helper that calls `measure` has to declare and forward these, or the
    /// compiler records the helper instead of the view. This is what that
    /// forwarding has to achieve.
    func testAWrapperForwardsItsOwnCallersLine() {
        func wrapper(file: String = #fileID, line: Int = #line) -> CallSite {
            CallSite(file: file, line: line)
        }
        let line = #line + 1
        let site = wrapper()

        XCTAssertEqual(site.line, line, "The wrapper must report where it was called, not where it is written")
    }

    func testAWrapperThatForgetsToForwardReportsItself() {
        // The failure mode, pinned so it stays understood rather than
        // rediscovered: this is what seventy identical call sites look like.
        func forgetfulWrapper() -> CallSite { CallSite() }
        let insideTheWrapper = #line - 1

        XCTAssertEqual(forgetfulWrapper().line, insideTheWrapper)
        XCTAssertEqual(forgetfulWrapper().line, forgetfulWrapper().line,
                       "Two different call sites, one answer — which is the bug")
    }

    func testLabelReadsAsAFileAndLine() {
        let site = CallSite(file: "PrismKitExample/ShopScreens.swift", line: 200)
        XCTAssertEqual(site.label, "ShopScreens.swift:200")
    }

    func testRoundTripCarriesTheCallSite() throws {
        let measurement = ResolvedMeasurement(
            group: "buyButton",
            role: .container,
            frame: CGRect(x: 16, y: 100, width: 158, height: 44),
            callSite: CallSite(file: "PrismKitExample/ShopScreens.swift", line: 200)
        )

        let data = try JSONEncoder().encode(measurement)
        let decoded = try JSONDecoder().decode(ResolvedMeasurement.self, from: data)

        XCTAssertEqual(decoded.callSite?.line, 200)
        XCTAssertEqual(decoded.callSite?.fileName, "ShopScreens.swift")
    }

    /// An app built against an older PrismKit streams measurements with no
    /// `callSite` key at all. The companion has to keep reading those rather
    /// than dropping the whole snapshot, so the field decodes as absent.
    func testMeasurementWithoutACallSiteStillDecodes() throws {
        let json = Data("""
        {
          "group": "buyButton",
          "role": {"container": {}},
          "frame": [[16, 100], [158, 44]],
          "metadata": {}
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(ResolvedMeasurement.self, from: json)

        XCTAssertNil(decoded.callSite)
        XCTAssertEqual(decoded.group, "buyButton")
    }
}
