import Combine
import CoreGraphics
import Foundation

/// A live size tweak for one instrumented view, sent companion → app.
/// `nil` dimensions leave that axis untouched.
public struct SizeOverride: Codable, Equatable, Sendable {
    /// The measurement id ("group#role") the override applies to.
    public let id: String
    public var width: CGFloat?
    public var height: CGFloat?

    /// Where the original content sits inside the overridden frame — one of
    /// `SizeOverride.alignments`. `nil` means center. Only meaningful while
    /// a width/height override grants extra space; interior stack alignment
    /// belongs to the app's own VStack/HStack parameters and cannot be
    /// changed from outside.
    public var alignment: String?

    /// Valid `alignment` values, laid out as a 3×3 grid.
    public static let alignments: [String] = [
        "topLeading", "top", "topTrailing",
        "leading", "center", "trailing",
        "bottomLeading", "bottom", "bottomTrailing",
    ]

    public init(
        id: String,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        alignment: String? = nil
    ) {
        self.id = id
        self.width = width
        self.height = height
        self.alignment = alignment
    }
}

/// The companion's full set of active overrides; each message replaces the
/// previous set, so clearing is just sending fewer entries.
public struct OverrideMessage: Codable, Equatable, Sendable {
    public var overrides: [SizeOverride]

    public init(overrides: [SizeOverride]) {
        self.overrides = overrides
    }
}

/// Overrides currently applied in the instrumented app. `measure(_:role:)`
/// observes this store and applies `.frame(width:height:)` to its view, so a
/// tweak from the companion re-lays-out the real UI immediately.
public final class MeasurementOverrideStore: ObservableObject {
    public static let shared = MeasurementOverrideStore()

    @Published public private(set) var sizes: [String: SizeOverride] = [:]

    public init() {}

    public func override(for id: String) -> SizeOverride? {
        sizes[id]
    }

    func apply(_ message: OverrideMessage) {
        var next: [String: SizeOverride] = [:]
        for override in message.overrides {
            next[override.id] = override
        }
        sizes = next
    }
}
