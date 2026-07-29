import CoreGraphics

/// The internal padding between a container frame and a content frame.
///
/// Values can be negative when the content extends outside its container,
/// which usually indicates a layout problem worth surfacing.
public struct InternalPadding: Equatable, Sendable {
    public var top: CGFloat
    public var leading: CGFloat
    public var bottom: CGFloat
    public var trailing: CGFloat

    public init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    /// Calculates the padding between a container frame and a content frame
    /// expressed in the same coordinate space.
    public static func between(container: CGRect, content: CGRect) -> InternalPadding {
        InternalPadding(
            top: content.minY - container.minY,
            leading: content.minX - container.minX,
            bottom: container.maxY - content.maxY,
            trailing: container.maxX - content.maxX
        )
    }

    /// Returns the padding with each edge rounded to whole points for display.
    public func rounded() -> InternalPadding {
        InternalPadding(
            top: top.rounded(),
            leading: leading.rounded(),
            bottom: bottom.rounded(),
            trailing: trailing.rounded()
        )
    }
}
