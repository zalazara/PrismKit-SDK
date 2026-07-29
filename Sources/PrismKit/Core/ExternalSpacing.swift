import CoreGraphics

/// The external spacing between two frames, measured per axis.
///
/// A gap is the empty distance between the closest edges along that axis.
/// When the frames overlap along an axis, the gap for that axis is zero.
public struct ExternalSpacing: Equatable, Sendable {
    /// Horizontal gap in points; zero when the frames overlap horizontally.
    public var horizontal: CGFloat

    /// Vertical gap in points; zero when the frames overlap vertically.
    public var vertical: CGFloat

    public init(horizontal: CGFloat, vertical: CGFloat) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    /// Calculates the spacing between two frames in the same coordinate space.
    /// The result is symmetric: argument order does not matter.
    public static func between(_ first: CGRect, _ second: CGRect) -> ExternalSpacing {
        ExternalSpacing(
            horizontal: axisGap(first.minX, first.maxX, second.minX, second.maxX),
            vertical: axisGap(first.minY, first.maxY, second.minY, second.maxY)
        )
    }

    /// Returns the spacing with each axis rounded to whole points for display.
    public func rounded() -> ExternalSpacing {
        ExternalSpacing(horizontal: horizontal.rounded(), vertical: vertical.rounded())
    }

    private static func axisGap(
        _ firstMin: CGFloat, _ firstMax: CGFloat,
        _ secondMin: CGFloat, _ secondMax: CGFloat
    ) -> CGFloat {
        if secondMin >= firstMax { return secondMin - firstMax }
        if firstMin >= secondMax { return firstMin - secondMax }
        return 0
    }
}
