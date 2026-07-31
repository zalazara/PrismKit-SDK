import CoreGraphics
import Foundation

/// Codable edge insets for transport (SwiftUI's `EdgeInsets` is not Codable).
public struct StreamInsets: Codable, Equatable, Sendable {
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

/// One frame of measurement data streamed from an instrumented app to the
/// PrismKit companion. All geometry is in points.
public struct MeasurementSnapshot: Codable, Equatable, Sendable {
    /// Display name of the app being measured.
    public var appName: String

    /// Bundle identifier of the app being measured. Lets tooling locate the
    /// installed app (e.g. to extract its icon).
    public var bundleID: String

    /// Full device screen size in points (used to map onto screenshots).
    public var screenSize: CGSize

    /// Device screen scale (points → pixels).
    public var screenScale: CGFloat

    /// The measurement scope's frame in the screen's global coordinate space.
    public var scopeFrame: CGRect

    /// Safe area insets of the scope.
    public var safeAreaInsets: StreamInsets

    /// Measurements in the scope's local coordinate space.
    public var measurements: [ResolvedMeasurement]

    /// The app's accessibility tree in reading order (screen coordinates),
    /// as assistive technologies see it.
    public var accessibilityElements: [AccessibilityElementInfo]

    /// The container hierarchy those elements live in (windows, scroll views,
    /// stacks…), for Xcode-style tree rendering. Leaf nodes reference
    /// `accessibilityElements` by index. Optional so snapshots saved before
    /// this field existed still decode.
    public var accessibilityTree: [AccessibilityTreeNode]?

    /// Values the app has offered to let the companion change, in the order it
    /// declared them. Optional so snapshots from before tweaks existed — and
    /// saved sessions written then — still decode.
    public var tweaks: [Tweak]?

    public init(
        appName: String,
        bundleID: String = "",
        screenSize: CGSize,
        screenScale: CGFloat,
        scopeFrame: CGRect,
        safeAreaInsets: StreamInsets,
        measurements: [ResolvedMeasurement],
        accessibilityElements: [AccessibilityElementInfo] = [],
        accessibilityTree: [AccessibilityTreeNode]? = nil,
        tweaks: [Tweak]? = nil
    ) {
        self.appName = appName
        self.bundleID = bundleID
        self.screenSize = screenSize
        self.screenScale = screenScale
        self.scopeFrame = scopeFrame
        self.safeAreaInsets = safeAreaInsets
        self.measurements = measurements
        self.accessibilityElements = accessibilityElements
        self.accessibilityTree = accessibilityTree
        self.tweaks = tweaks
    }

    /// The frame of a measurement converted to screen (global) coordinates.
    public func globalFrame(for measurement: ResolvedMeasurement) -> CGRect {
        measurement.frame.offsetBy(dx: scopeFrame.minX, dy: scopeFrame.minY)
    }

    /// Elements derived automatically from the accessibility tree: everything
    /// assistive technologies expose becomes selectable and measurable with
    /// zero `.measure()` instrumentation — the SDK only needs `measureScope`
    /// at the root. Frames are converted from screen to scope-local
    /// coordinates; numbering matches the companion's accessibility badges.
    ///
    /// `.measure()` remains an optional enrichment for semantics the system
    /// cannot infer (container/content padding, design-system grouping).
    public var automaticMeasurements: [ResolvedMeasurement] {
        // Image identity (SF Symbol / asset name) captured on the tree node
        // for elements backed by UIImageView.
        var detailByIndex: [Int: String] = [:]
        if let accessibilityTree {
            func collect(_ nodes: [AccessibilityTreeNode]) {
                for node in nodes {
                    if let index = node.elementIndex, let detail = node.detail {
                        detailByIndex[index] = detail
                    }
                    collect(node.children)
                }
            }
            collect(accessibilityTree)
        }
        return accessibilityElements.enumerated().map { index, element in
            var metadata: [String: String] = ["reads": element.spokenDescription]
            if let identifier = element.identifier, !identifier.isEmpty {
                metadata["identifier"] = identifier
            }
            if !element.traits.isEmpty {
                metadata["traits"] = element.traits.joined(separator: ", ")
            }
            if let detail = detailByIndex[index] {
                metadata["asset"] = detail
            }
            return ResolvedMeasurement(
                group: Self.automaticName(for: element, index: index),
                role: .custom("element"),
                frame: element.frame.offsetBy(dx: -scopeFrame.minX, dy: -scopeFrame.minY),
                metadata: metadata
            )
        }
    }

    /// Selectable measurements for the hierarchy's visual leaf nodes — the
    /// rendered Text/Image views living inside merged accessibility elements
    /// (a SwiftUI row reads as ONE element, but its image and texts are
    /// still individually measurable through these). Identified by their
    /// tree path so both sides derive identical ids. Containers are excluded
    /// on purpose: clicking empty space must keep clearing the selection.
    public var treeMeasurements: [ResolvedMeasurement] {
        guard let accessibilityTree else { return [] }
        var collected: [ResolvedMeasurement] = []
        func walk(_ nodes: [AccessibilityTreeNode], path: String) {
            for (index, node) in nodes.enumerated() {
                let id = path.isEmpty ? "\(index)" : "\(path).\(index)"
                if node.elementIndex == nil, node.children.isEmpty {
                    var metadata = ["class": node.className]
                    if let detail = node.detail {
                        metadata["asset"] = detail
                    }
                    collected.append(
                        ResolvedMeasurement(
                            group: "\(node.className) · \(id)",
                            role: .custom("view"),
                            frame: node.frame.offsetBy(dx: -scopeFrame.minX, dy: -scopeFrame.minY),
                            metadata: metadata
                        )
                    )
                }
                walk(node.children, path: id)
            }
        }
        walk(accessibilityTree, path: "")
        return collected
    }

    /// Instrumented, automatic, and visual-leaf elements together — the set
    /// tools should hit-test and select from.
    public var allMeasurements: [ResolvedMeasurement] {
        measurements + automaticMeasurements + treeMeasurements
    }

    private static func automaticName(for element: AccessibilityElementInfo, index: Int) -> String {
        let base = element.identifier.flatMap { $0.isEmpty ? nil : $0 }
            ?? element.label.flatMap { $0.isEmpty ? nil : $0 }
            ?? element.traits.first
            ?? "element"
        let short = base.count > 22 ? String(base.prefix(22)) + "…" : base
        return "\(index + 1) · \(short)"
    }
}

/// The TCP port the companion listens on and instrumented apps connect to.
/// The iOS Simulator shares the host's loopback interface, so no discovery
/// is needed for the simulator workflow.
public enum MeasureStreamDefaults {
    public static let port: UInt16 = 9294

    /// The effective port, honoring the `PRISMKIT_PORT` environment
    /// variable (pass it to a simulator app with `SIMCTL_CHILD_PRISMKIT_PORT`).
    public static var resolvedPort: UInt16 {
        if let raw = ProcessInfo.processInfo.environment["PRISMKIT_PORT"],
           let value = UInt16(raw) {
            return value
        }
        return port
    }
}
