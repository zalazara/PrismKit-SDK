import CoreGraphics
import Foundation

/// A design, described in a way no design tool owns.
///
/// PrismKit deliberately does not talk to Figma, Pencil, or anything else:
/// the agent already has those connected, so it reads the node there and
/// hands over this. Adding a new design source is then a mapping the agent
/// performs, not code that ships here — and PrismKit never touches anyone's
/// credentials.
///
/// Geometry is in design points, with node frames relative to the design
/// frame's top-left corner. The comparator scales them onto the device.
public struct DesignSpec: Codable, Equatable, Sendable {
    /// Where this came from ("figma", "pencil", …). Free-form; carried into
    /// the report so a finding can be traced back.
    public var source: String?

    /// A pointer back to the original — a node URL, a file id, anything that
    /// helps a human re-open it.
    public var reference: String?

    /// The design frame's own size. The comparator uses its width to work out
    /// the scale onto the device, so a 390 pt mock and a 1170 px export both
    /// line up.
    public var frame: DesignSize

    /// The nodes to check. A partial list is fine and expected — describe the
    /// components that matter, not every layer.
    public var nodes: [DesignNode]

    public init(
        source: String? = nil,
        reference: String? = nil,
        frame: DesignSize,
        nodes: [DesignNode]
    ) {
        self.source = source
        self.reference = reference
        self.frame = frame
        self.nodes = nodes
    }
}

public struct DesignSize: Codable, Equatable, Sendable {
    public var width: CGFloat
    public var height: CGFloat

    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }
}

/// Spelled out field by field rather than reusing `CGRect`, whose Codable
/// form is a nested array — this JSON is written by an agent, so it has to
/// read like something a human would write.
public struct DesignRect: Codable, Equatable, Sendable {
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(_ rect: CGRect) {
        self.init(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
    }

    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

public struct DesignEdges: Codable, Equatable, Sendable {
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
}

/// One element of the design. Everything except `id` and `frame` is optional:
/// a sparse source contributes less, a rich one contributes more, and the
/// comparator checks whatever it was given.
public struct DesignNode: Codable, Equatable, Sendable {
    /// Stable id in the source document.
    public var id: String

    /// Human-readable name. Also used for pairing when it matches a
    /// `.measure()` group or an accessibility identifier.
    public var name: String?

    /// An explicit pairing hint — the measurement id, `.measure()` group, or
    /// `accessibilityIdentifier` this node corresponds to. Set it and the
    /// pairing stops being a guess, which is the difference between a report
    /// you can trust and one you have to double-check.
    public var match: String?

    /// Frame relative to the design frame's top-left, in design points.
    public var frame: DesignRect

    /// The copy this node renders, if any. Used both to pair with an
    /// on-screen element and to catch wording that drifted.
    public var text: String?

    /// Internal padding, when the design expresses it.
    public var padding: DesignEdges?

    public init(
        id: String,
        name: String? = nil,
        match: String? = nil,
        frame: DesignRect,
        text: String? = nil,
        padding: DesignEdges? = nil
    ) {
        self.id = id
        self.name = name
        self.match = match
        self.frame = frame
        self.text = text
        self.padding = padding
    }

    /// What to call this node in a report.
    public var label: String { name ?? id }
}
