import XCTest
@testable import PrismKit

final class TweakTests: XCTestCase {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func testEachValueKindSurvivesTheRoundTrip() throws {
        let values: [TweakValue] = [.number(16.5), .boolean(true), .text("Buy now")]

        for value in values {
            let decoded = try decoder.decode(TweakValue.self, from: encoder.encode(value))
            XCTAssertEqual(decoded, value)
        }
    }

    func testBoundsTravelWithTheTweak() throws {
        let tweak = Tweak(name: "Card padding", value: .number(16), minimum: 0, maximum: 48)

        let decoded = try decoder.decode(Tweak.self, from: encoder.encode(tweak))

        XCTAssertEqual(decoded.minimum, 0)
        XCTAssertEqual(decoded.maximum, 48)
    }

    /// Absent bounds have to stay absent. Substituting a default would put a
    /// slider on screen with limits nobody chose, which reads as a statement
    /// about the value's range rather than as the guess it is.
    func testATweakWithoutBoundsKeepsNone() throws {
        let tweak = Tweak(name: "Title", value: .text("Shop"))

        let decoded = try decoder.decode(Tweak.self, from: encoder.encode(tweak))

        XCTAssertNil(decoded.minimum)
        XCTAssertNil(decoded.maximum)
    }

    func testATweakMessageIsNotAnOverrideMessage() throws {
        let tweaks = try encoder.encode(TweakMessage(tweaks: ["Card padding": .number(20)]))
        let overrides = try encoder.encode(OverrideMessage(overrides: [SizeOverride(id: "a#container")]))

        XCTAssertNil(try? decoder.decode(OverrideMessage.self, from: tweaks),
                     "The app reads overrides first; a tweak that also parsed as one would clear every size override")
        XCTAssertNil(try? decoder.decode(TweakMessage.self, from: overrides))
    }

    /// A snapshot from before tweaks existed — or a session saved then — has
    /// no such key, and must still open.
    func testASnapshotWithoutTweaksStillDecodes() throws {
        let snapshot = MeasurementSnapshot(
            appName: "A",
            bundleID: "b",
            screenSize: CGSize(width: 393, height: 852),
            screenScale: 3,
            scopeFrame: .zero,
            safeAreaInsets: StreamInsets(top: 0, leading: 0, bottom: 0, trailing: 0),
            measurements: []
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try encoder.encode(snapshot)) as? [String: Any]
        )
        object.removeValue(forKey: "tweaks")
        let data = try JSONSerialization.data(withJSONObject: object)

        let decoded = try decoder.decode(MeasurementSnapshot.self, from: data)

        XCTAssertNil(decoded.tweaks)
    }

    #if DEBUG

    @MainActor
    func testTheRegistryKeepsTheOrderTheAppDeclaredThemIn() {
        let registry = TweakRegistry.shared
        for name in ["Card padding", "Row spacing", "Show badges"] {
            registry.forget(name)
        }

        registry.register(Tweak(name: "Card padding", value: .number(16)), write: { _ in })
        registry.register(Tweak(name: "Row spacing", value: .number(8)), write: { _ in })
        registry.register(Tweak(name: "Show badges", value: .boolean(true)), write: { _ in })
        // Re-registering on a view update must not reorder anything.
        registry.register(Tweak(name: "Card padding", value: .number(18)), write: { _ in })

        let names = registry.current.map(\.name)
        XCTAssertEqual(names, ["Card padding", "Row spacing", "Show badges"])
        XCTAssertEqual(registry.current.first?.value, .number(18), "The latest value, in the original position")

        for name in names { registry.forget(name) }
    }

    @MainActor
    func testApplyingWritesThroughToTheBinding() {
        let registry = TweakRegistry.shared
        var written: Double?
        registry.register(Tweak(name: "Card padding", value: .number(16))) { value in
            written = value.number
        }

        registry.apply(TweakMessage(tweaks: ["Card padding": .number(24)]))

        XCTAssertEqual(written, 24)
        registry.forget("Card padding")
    }

    @MainActor
    func testTheFirstValueOfferedIsRememberedAsTheDefault() {
        let registry = TweakRegistry.shared
        registry.forget("Card padding")

        registry.register(Tweak(name: "Card padding", value: .number(16)), write: { _ in })
        // A view update re-registers with whatever the value is now. Taking
        // that as the default would redefine "original" as "current" and
        // there would be nothing to go back to.
        registry.register(Tweak(name: "Card padding", value: .number(31)), write: { _ in })

        let tweak = registry.current.first { $0.name == "Card padding" }
        XCTAssertEqual(tweak?.value, .number(31))
        XCTAssertEqual(tweak?.defaultValue, .number(16))
        XCTAssertEqual(tweak?.isChanged, true)

        registry.forget("Card padding")
    }

    @MainActor
    func testAScreenThatComesBackOffersItsOriginalAgain() {
        let registry = TweakRegistry.shared
        registry.forget("Title")

        registry.register(Tweak(name: "Title", value: .text("Shop")), write: { _ in })
        registry.register(Tweak(name: "Title", value: .text("Edited")), write: { _ in })
        // Navigating away and back rebuilds the state from the source, so the
        // value offered next is the original — and it has to count as one.
        registry.forget("Title")
        registry.register(Tweak(name: "Title", value: .text("Shop")), write: { _ in })

        let tweak = registry.current.first { $0.name == "Title" }
        XCTAssertEqual(tweak?.defaultValue, .text("Shop"))
        XCTAssertEqual(tweak?.isChanged, false)

        registry.forget("Title")
    }

    /// A snapshot from an app built before defaults were carried.
    func testATweakWithoutADefaultOffersNoReset() throws {
        let json = Data(#"{"name":"Card padding","value":{"number":{"_0":16}}}"#.utf8)
        let decoded = try decoder.decode(Tweak.self, from: json)

        XCTAssertNil(decoded.defaultValue)
        XCTAssertFalse(decoded.isChanged, "With nothing to go back to there is nothing to offer")
    }

    @MainActor
    func testAnUnknownNameIsIgnoredRatherThanFatal() {
        // A tweak can disappear while a message about it is in flight.
        TweakRegistry.shared.apply(TweakMessage(tweaks: ["Gone": .number(1)]))
    }

    #endif
}
