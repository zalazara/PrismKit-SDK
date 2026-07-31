import XCTest
@testable import PrismKit

@MainActor
final class RenderPolicyTests: XCTestCase {
    override func tearDown() {
        PrismKit.rendersComponent = nil
        super.tearDown()
    }

    // The registry itself is compiled out of release builds along with the
    // rest of the instrumentation, so the tests that exercise it can only run
    // where it exists. The wire-format tests below run in both.
    #if DEBUG

    func testNoPolicyRefusesNothing() {
        PrismKit.rendersComponent = nil

        let result = SoloRenderRegistry.render(
            ids: ["payment-card#container"],
            sizes: ["payment-card#container": CGSize(width: 100, height: 40)],
            scale: 3
        )

        XCTAssertTrue(result.refused.isEmpty, "The default has to be permissive, or the feature arrives already broken")
    }

    func testARefusedComponentIsReportedRatherThanDroppedQuietly() {
        PrismKit.rendersComponent = { !$0.hasPrefix("payment-") }

        let result = SoloRenderRegistry.render(
            ids: ["payment-card#container", "title#container"],
            sizes: [
                "payment-card#container": CGSize(width: 100, height: 40),
                "title#container": CGSize(width: 100, height: 20),
            ],
            scale: 3
        )

        XCTAssertEqual(result.refused, ["payment-card#container"])
        XCTAssertTrue(
            result.rendered.isEmpty,
            "Neither was registered, so neither draws — but only one of them was refused, and that difference is the point"
        )
    }

    /// The policy is asked before anything is drawn. Otherwise a refused
    /// component would still be rendered — the expensive half — and only then
    /// thrown away, which defeats both reasons for having it.
    func testTheRefusalHappensBeforeAnyDrawing() {
        var asked: [String] = []
        PrismKit.rendersComponent = { id in
            asked.append(id)
            return false
        }

        _ = SoloRenderRegistry.render(
            ids: ["a#container", "b#container"],
            sizes: [:],
            scale: 3
        )

        XCTAssertEqual(asked, ["a#container", "b#container"],
                       "Asked for every id, including ones with no size — the app's answer comes first")
    }

    #endif

    func testTheMessageCarriesRefusalsSeparatelyFromPictures() throws {
        let message = ComponentRenderMessage(
            id: "c1",
            components: [],
            refused: ["payment-card#container"]
        )

        let decoded = try JSONDecoder().decode(
            ComponentRenderMessage.self,
            from: JSONEncoder().encode(message)
        )

        XCTAssertEqual(decoded.refused, ["payment-card#container"])
    }

    /// An app built before refusals existed sends a message without the key.
    func testAMessageWithoutRefusalsStillDecodes() throws {
        let json = Data("""
        {"id": "c1", "components": []}
        """.utf8)

        let decoded = try JSONDecoder().decode(ComponentRenderMessage.self, from: json)

        XCTAssertTrue(decoded.refused.isEmpty)
    }
}
