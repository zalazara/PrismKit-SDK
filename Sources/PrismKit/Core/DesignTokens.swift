import CoreGraphics
import Foundation

/// The spacing scale a team actually uses.
///
/// Everything that judges a measurement — the off-token warnings in the
/// overlay, the alignment audit, the agent's report — has to agree on this,
/// or the tool confidently flags correct code.
public struct DesignTokens: Codable, Equatable, Sendable {
    /// Valid spacing values in points.
    public var spacingTokens: [CGFloat]

    /// Alignment grid cell size in points.
    public var gridSize: CGFloat

    public init(
        spacingTokens: [CGFloat] = MeasureConfiguration.default.spacingTokens,
        gridSize: CGFloat = MeasureConfiguration.default.gridSize
    ) {
        self.spacingTokens = spacingTokens.sorted()
        self.gridSize = gridSize
    }

    public static let `default` = DesignTokens()

    /// Applies the tokens to a configuration, leaving its layer toggles alone.
    public func applied(to configuration: MeasureConfiguration) -> MeasureConfiguration {
        var updated = configuration
        updated.spacingTokens = spacingTokens
        updated.gridSize = gridSize
        return updated
    }
}

#if os(macOS)

/// Finds the team's tokens, and remembers them.
///
/// Resolution runs from most specific to least: a `.prismkit.json` next to the
/// project (or in any parent directory), then a machine-wide file, then the
/// built-in scale. The project file is the one that matters — it is versioned
/// with the code, so the whole team and CI judge spacing by the same numbers
/// instead of by whatever each machine happens to have configured.
public enum DesignTokensStore {
    public static let projectFileName = ".prismkit.json"

    /// Where a resolved set of tokens came from, so a report can say so. A
    /// number that fails validation is only actionable if you know which
    /// scale rejected it.
    public enum Origin: Equatable, Sendable {
        case project(path: String)
        case machine
        case builtIn

        public var describedForTooling: String {
            switch self {
            case .project(let path): return "project file at \(path)"
            case .machine: return "this Mac's PrismKit settings"
            case .builtIn: return "PrismKit's built-in scale"
            }
        }
    }

    public struct Resolved: Equatable, Sendable {
        public let tokens: DesignTokens
        public let origin: Origin
    }

    public static var machineURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("PrismKit", isDirectory: true)
            .appendingPathComponent("design-tokens.json")
    }

    /// - Parameter projectDirectory: where to start looking for a project
    ///   file. Passing the working directory is usually right: an agent runs
    ///   inside the repository it is fixing.
    public static func resolve(projectDirectory: String? = nil) -> Resolved {
        if let projectDirectory,
           let found = findProjectFile(startingAt: URL(fileURLWithPath: projectDirectory)),
           let tokens = decode(at: found) {
            return Resolved(tokens: tokens, origin: .project(path: found.path))
        }
        if let tokens = decode(at: machineURL) {
            return Resolved(tokens: tokens, origin: .machine)
        }
        return Resolved(tokens: .default, origin: .builtIn)
    }

    @discardableResult
    public static func saveForMachine(_ tokens: DesignTokens) -> Bool {
        write(tokens, to: machineURL)
    }

    /// Writes `.prismkit.json` into a directory, for committing alongside the
    /// code it describes.
    @discardableResult
    public static func writeProjectFile(_ tokens: DesignTokens, in directory: String) -> URL? {
        let url = URL(fileURLWithPath: directory).appendingPathComponent(projectFileName)
        return write(tokens, to: url) ? url : nil
    }

    /// Walks up from `directory` looking for a project file, so it works from
    /// a nested folder the way every other project-config convention does.
    public static func findProjectFile(startingAt directory: URL) -> URL? {
        var current = directory.standardizedFileURL
        // Bounded rather than looping to "/" forever on a malformed path.
        for _ in 0..<12 {
            let candidate = current.appendingPathComponent(projectFileName)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            let parent = current.deletingLastPathComponent().standardizedFileURL
            if parent == current { break }
            current = parent
        }
        return nil
    }

    private static func decode(at url: URL) -> DesignTokens? {
        guard let data = try? Data(contentsOf: url),
              let tokens = try? JSONDecoder().decode(DesignTokens.self, from: data),
              !tokens.spacingTokens.isEmpty else { return nil }
        return tokens
    }

    private static func write(_ tokens: DesignTokens, to url: URL) -> Bool {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(tokens) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}

#endif
