import XCTest
@testable import PrismKit

/// Both directions of this socket carry more than one kind of message and no
/// envelope says which. That works only while the shapes cannot be mistaken
/// for one another, so that is what these check.
final class StreamProbeTests: XCTestCase {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func testProbeRoundTrip() throws {
        let ping = try decoder.decode(
            PingMessage.self,
            from: encoder.encode(PingMessage(ping: "p7"))
        )
        XCTAssertEqual(ping.ping, "p7")

        let pong = try decoder.decode(
            PongMessage.self,
            from: encoder.encode(PongMessage(pong: "p7"))
        )
        XCTAssertEqual(pong.pong, "p7")
    }

    func testAProbeIsNotAnOverrideAndAnOverrideIsNotAProbe() throws {
        let override = try encoder.encode(OverrideMessage(overrides: [SizeOverride(id: "a#container")]))
        let ping = try encoder.encode(PingMessage(ping: "p1"))

        XCTAssertNil(try? decoder.decode(PingMessage.self, from: override),
                     "The app reads overrides first; an override that also parsed as a ping would be answered instead of applied")
        XCTAssertNil(try? decoder.decode(OverrideMessage.self, from: ping),
                     "A ping that parsed as an override would clear every active size tweak")
    }

    func testAPingIsNotAPong() throws {
        let ping = try encoder.encode(PingMessage(ping: "p1"))
        XCTAssertNil(try? decoder.decode(PongMessage.self, from: ping),
                     "Both travel the same socket in opposite directions; confusing them would have the server answer itself")
    }

    /// The server only attempts a pong decode on lines under 64 bytes, to
    /// avoid parsing every (much larger) snapshot twice. That shortcut is only
    /// correct while a pong actually is small.
    func testAPongStaysUnderTheLengthTheServerScreensOn() throws {
        // Far more probes than any session will send before reconnecting.
        let pong = try encoder.encode(PongMessage(pong: "p999999999"))
        XCTAssertLessThan(pong.count, 64)
    }

    func testASnapshotIsNotMistakenForAPong() throws {
        let snapshot = MeasurementSnapshot(
            appName: "A",
            bundleID: "b",
            screenSize: CGSize(width: 393, height: 852),
            screenScale: 3,
            scopeFrame: .zero,
            safeAreaInsets: StreamInsets(top: 0, leading: 0, bottom: 0, trailing: 0),
            measurements: []
        )
        let data = try encoder.encode(snapshot)
        XCTAssertNil(try? decoder.decode(PongMessage.self, from: data))
    }
}
