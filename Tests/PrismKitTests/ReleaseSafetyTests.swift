import SwiftUI
import XCTest
@testable import PrismKit

/// PrismKit walks the accessibility tree — which carries what the user typed
/// into fields — and streams it over a socket. That must never happen in a
/// shipping app, and "must never" is worth a test rather than a convention.
///
/// The release half of these assertions only runs under `swift test -c release`,
/// so CI has to run both configurations for this to be worth anything.
final class ReleaseSafetyTests: XCTestCase {
    func testInstrumentationFollowsBuildConfiguration() {
        #if DEBUG
        XCTAssertTrue(
            PrismKit.isEnabled,
            "Debug builds are the whole point of the tool — collection must be on."
        )
        #else
        XCTAssertFalse(
            PrismKit.isEnabled,
            "Release builds must not collect or stream anything."
        )
        #endif
    }

    /// In release the modifier has to disappear entirely, not merely go quiet:
    /// the returned view must be the *same type* as the one passed in.
    func testMeasureScopeCompilesOutOfReleaseBuilds() {
        let plain = Color.clear
        let scoped = plain.measureScope()

        #if DEBUG
        XCTAssertFalse(
            type(of: scoped) == type(of: plain),
            "Debug builds must install the measurement scope."
        )
        #else
        XCTAssertTrue(
            type(of: scoped) == type(of: plain),
            "Release builds must return the view untouched — no scope, no socket."
        )
        #endif
    }

    func testMeasureCompilesOutOfReleaseBuilds() {
        let plain = Color.clear
        let measured = plain.measure("button", role: .container)

        #if DEBUG
        XCTAssertFalse(
            type(of: measured) == type(of: plain),
            "Debug builds must report the measurement."
        )
        #else
        XCTAssertTrue(
            type(of: measured) == type(of: plain),
            "Release builds must return the view untouched — nothing reported, no size override applied."
        )
        #endif
    }
}
