import CoreGraphics
import Foundation

/// One component drawn on its own, without the instrumented views nested
/// inside it.
///
/// Why not crop the screen: a crop of a container carries everything drawn on
/// top of it, so a stack of cropped containers is a pile of paper. Lookin and
/// Reveal both arrived at the same answer — two pictures per view, one with
/// children and one without — after finding that stacking single images by
/// z-order does not reproduce the screen either, since clipping and masking
/// are not layers piled up.
///
/// Only the "without" half travels. The other half is a crop of a screen frame
/// the companion already holds.
public struct ComponentRender: Codable, Equatable, Sendable {
    /// The measurement id ("group#role") this is a picture of.
    public let id: String

    /// Size in points, matching the measured frame.
    public let width: CGFloat
    public let height: CGFloat
    public let scale: CGFloat

    /// PNG, lossless for the same reason the screen frame is.
    public let png: Data

    public init(id: String, width: CGFloat, height: CGFloat, scale: CGFloat, png: Data) {
        self.id = id
        self.width = width
        self.height = height
        self.scale = scale
        self.png = png
    }
}

/// Companion → app: "draw these components on their own".
///
/// Named rather than "all of them" because the caller usually wants a few: the
/// selection, or the containers at one level of the tree. Drawing every
/// instrumented view on a busy screen is real work on the app's main thread,
/// and the Mac is the only side that knows how much of it is wanted.
public struct ComponentRenderRequestMessage: Codable, Equatable, Sendable {
    public let requestComponents: String
    /// Measurement ids, as they appear in the snapshot.
    public let ids: [String]

    public init(requestComponents: String, ids: [String]) {
        self.requestComponents = requestComponents
        self.ids = ids
    }
}

/// App → companion: the components that could be drawn.
///
/// Fewer than were asked for is normal and not an error: a component can be
/// off screen, or the app can be on an OS too old to render a view off screen
/// at all. The companion is expected to fall back to a crop for anything
/// missing, which is a worse picture rather than no picture.
public struct ComponentRenderMessage: Codable, Equatable, Sendable {
    public let id: String
    public let components: [ComponentRender]

    /// Components the app declined to draw, via `PrismKit.rendersComponent`.
    ///
    /// Reported rather than left out silently, because "your app is set not to
    /// send a picture of this" and "there is no picture" lead somewhere
    /// different: the first is a line of code somebody wrote on purpose, and a
    /// tool that shows a blank instead of saying so sends them looking for a
    /// bug that is not there.
    public var refused: [String]

    public init(id: String, components: [ComponentRender], refused: [String] = []) {
        self.id = id
        self.components = components
        self.refused = refused
    }

    /// Decoded by hand so a message from an app built before refusals existed
    /// still arrives. The synthesised version demands the key for a
    /// non-optional property, which would throw away the whole message —
    /// pictures included — over a field that app has no opinion about.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        components = try container.decode([ComponentRender].self, forKey: .components)
        refused = try container.decodeIfPresent([String].self, forKey: .refused) ?? []
    }
}
