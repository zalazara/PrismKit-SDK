import Foundation

#if os(macOS)

/// The design currently being checked against, shared between the MCP server
/// and the companion app.
///
/// They cannot hold it in memory together: both bind port 9294, so only one
/// runs at a time. A small file in Application Support lets an agent attach a
/// design in one session and the person open the companion afterwards and see
/// the same thing — and it survives either process restarting.
///
/// macOS-only: this is tooling state, not something a measured app carries.
public enum AttachedDesignStore {
    /// A design plus where it came from, as written to disk.
    public struct Attachment: Codable, Equatable, Sendable {
        public var design: DesignSpec
        /// Unix time it was attached, so a stale design can be spotted.
        public var attachedAt: Double
        /// Optional path to a rendered image of the design, for the
        /// companion's side-by-side and overlay modes.
        public var imagePath: String?

        public init(design: DesignSpec, attachedAt: Double, imagePath: String? = nil) {
            self.design = design
            self.attachedAt = attachedAt
            self.imagePath = imagePath
        }
    }

    public static var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("PrismKit", isDirectory: true)
            .appendingPathComponent("attached-design.json")
    }

    public static func load() -> Attachment? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Attachment.self, from: data)
    }

    @discardableResult
    public static func save(_ attachment: Attachment) -> Bool {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(attachment) else { return false }
        // Atomic so a companion reading while the MCP writes never sees half
        // a file — they are separate processes with no lock between them.
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    public static func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}

#endif
