import CoreGraphics
import XCTest
@testable import PrismKit

/// The spacing scale decides which measurements get flagged, so resolving it
/// wrongly means confidently rejecting correct code. These cover the order
/// the sources are consulted in and the walk that finds a project file.
final class DesignTokensTests: XCTestCase {
    private var sandbox: URL!

    override func setUpWithError() throws {
        sandbox = FileManager.default.temporaryDirectory
            .appendingPathComponent("prismkit-tokens-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: sandbox)
    }

    private func writeProjectFile(_ tokens: DesignTokens, in directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(tokens)
        try data.write(to: directory.appendingPathComponent(DesignTokensStore.projectFileName))
    }

    func testFallsBackToTheBuiltInScaleWhenNothingIsConfigured() {
        let resolved = DesignTokensStore.resolve(projectDirectory: sandbox.path)

        // The machine file may or may not exist on the machine running this,
        // so only the project half is asserted here.
        XCTAssertNotEqual(
            resolved.origin,
            .project(path: sandbox.path),
            "An empty directory holds no project file"
        )
    }

    func testProjectFileWins() throws {
        let tokens = DesignTokens(spacingTokens: [5, 10, 20, 40], gridSize: 5)
        try writeProjectFile(tokens, in: sandbox)

        let resolved = DesignTokensStore.resolve(projectDirectory: sandbox.path)

        XCTAssertEqual(resolved.tokens.spacingTokens, [5, 10, 20, 40])
        XCTAssertEqual(resolved.tokens.gridSize, 5)
        XCTAssertEqual(
            resolved.origin,
            .project(path: sandbox.appendingPathComponent(".prismkit.json").path),
            "A project file must beat both the machine file and the built-in scale"
        )
    }

    func testProjectFileIsFoundFromANestedDirectory() throws {
        try writeProjectFile(DesignTokens(spacingTokens: [6, 12, 18]), in: sandbox)
        let nested = sandbox
            .appendingPathComponent("Sources")
            .appendingPathComponent("Feature")
            .appendingPathComponent("Detail")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        let resolved = DesignTokensStore.resolve(projectDirectory: nested.path)

        XCTAssertEqual(
            resolved.tokens.spacingTokens,
            [6, 12, 18],
            "Resolution must walk up, like every other project-config convention"
        )
    }

    func testAMalformedProjectFileIsIgnoredRatherThanCrashing() throws {
        try "not json at all".write(
            to: sandbox.appendingPathComponent(DesignTokensStore.projectFileName),
            atomically: true,
            encoding: .utf8
        )

        let resolved = DesignTokensStore.resolve(projectDirectory: sandbox.path)

        XCTAssertFalse(resolved.tokens.spacingTokens.isEmpty, "A broken file must not leave the tool with no scale")
        if case .project = resolved.origin {
            XCTFail("A file that does not decode must not be reported as the source")
        }
    }

    func testAnEmptyScaleIsRejected() throws {
        try writeProjectFile(DesignTokens(spacingTokens: []), in: sandbox)

        let resolved = DesignTokensStore.resolve(projectDirectory: sandbox.path)

        XCTAssertFalse(
            resolved.tokens.spacingTokens.isEmpty,
            "An empty scale would validate nothing; fall through instead"
        )
    }

    func testWritingAProjectFileRoundTrips() throws {
        let tokens = DesignTokens(spacingTokens: [2, 4, 8, 16], gridSize: 4)

        let url = DesignTokensStore.writeProjectFile(tokens, in: sandbox.path)

        XCTAssertNotNil(url)
        XCTAssertEqual(DesignTokensStore.resolve(projectDirectory: sandbox.path).tokens, tokens)
    }

    func testTokensAreSortedSoNearestTokenHintsAreStable() {
        let tokens = DesignTokens(spacingTokens: [16, 4, 24, 8])

        XCTAssertEqual(tokens.spacingTokens, [4, 8, 16, 24])
    }

    func testApplyingTokensLeavesLayerTogglesAlone() {
        let configuration = MeasureConfiguration(showsGrid: true, showsBounds: false)
        let tokens = DesignTokens(spacingTokens: [7, 14], gridSize: 7)

        let applied = tokens.applied(to: configuration)

        XCTAssertEqual(applied.spacingTokens, [7, 14])
        XCTAssertEqual(applied.gridSize, 7)
        XCTAssertTrue(applied.showsGrid, "Applying a scale must not reset what the user is looking at")
        XCTAssertFalse(applied.showsBounds)
    }

    /// The whole point of the phase: a team scale that actually changes what
    /// gets flagged.
    func testTheResolvedScaleDecidesWhatCountsAsOffToken() {
        let teamTokens = DesignTokens(spacingTokens: [5, 10, 15, 20])

        let defaultVerdict = SpacingTokenValidator.validate(10, tokens: DesignTokens.default.spacingTokens)
        let teamVerdict = SpacingTokenValidator.validate(10, tokens: teamTokens.spacingTokens)

        XCTAssertFalse(defaultVerdict.isValid, "10 pt is not on PrismKit's built-in scale")
        XCTAssertTrue(teamVerdict.isValid, "…but it is on this team's, and that is the scale that matters")
    }
}
