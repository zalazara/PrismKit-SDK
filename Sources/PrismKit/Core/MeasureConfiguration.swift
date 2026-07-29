import CoreGraphics

/// Configuration for the measurement overlay.
///
/// All values have practical defaults so `MeasureConfiguration.default` works
/// out of the box for typical iOS design systems.
public struct MeasureConfiguration: Equatable, Sendable {
    /// Grid cell size in points. Defaults to 8.
    public var gridSize: CGFloat

    /// Valid spacing values, in points, for token validation.
    public var spacingTokens: [CGFloat]

    /// Whether the alignment grid is drawn.
    public var showsGrid: Bool

    /// Whether the safe area boundary is drawn.
    public var showsSafeArea: Bool

    /// Whether measured frames show dashed bounds.
    public var showsBounds: Bool

    /// Whether measured frames show width × height labels.
    public var showsSizeLabels: Bool

    /// Whether internal padding is displayed for container/content pairs.
    public var showsInternalPadding: Bool

    /// Whether external spacing between selected elements is displayed.
    public var showsExternalSpacing: Bool

    /// Whether spacing and padding values are validated against `spacingTokens`.
    public var validatesTokens: Bool

    public init(
        gridSize: CGFloat = 8,
        spacingTokens: [CGFloat] = [4, 8, 12, 16, 24, 32, 40, 48],
        showsGrid: Bool = false,
        showsSafeArea: Bool = false,
        showsBounds: Bool = true,
        showsSizeLabels: Bool = true,
        showsInternalPadding: Bool = true,
        showsExternalSpacing: Bool = true,
        validatesTokens: Bool = true
    ) {
        self.gridSize = gridSize
        self.spacingTokens = spacingTokens
        self.showsGrid = showsGrid
        self.showsSafeArea = showsSafeArea
        self.showsBounds = showsBounds
        self.showsSizeLabels = showsSizeLabels
        self.showsInternalPadding = showsInternalPadding
        self.showsExternalSpacing = showsExternalSpacing
        self.validatesTokens = validatesTokens
    }

    public static let `default` = MeasureConfiguration()
}
