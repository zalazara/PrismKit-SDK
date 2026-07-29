import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// One element as assistive technologies see it: what VoiceOver focuses,
/// where it is, and what it will read.
public struct AccessibilityElementInfo: Codable, Equatable, Sendable {
    /// The accessibility label (the primary thing VoiceOver reads).
    public var label: String?
    /// The current value (e.g. a slider's value or text contents).
    public var value: String?
    /// The hint read after a pause.
    public var hint: String?
    /// The `accessibilityIdentifier`, used by UI tests.
    public var identifier: String?
    /// Readable trait names ("button", "header", "image", …).
    public var traits: [String]
    /// The element's frame in screen coordinates, in points.
    public var frame: CGRect

    public init(
        label: String? = nil,
        value: String? = nil,
        hint: String? = nil,
        identifier: String? = nil,
        traits: [String] = [],
        frame: CGRect
    ) {
        self.label = label
        self.value = value
        self.hint = hint
        self.identifier = identifier
        self.traits = traits
        self.frame = frame
    }

    /// An approximation of what VoiceOver will announce for this element.
    public var spokenDescription: String {
        var parts: [String] = []
        if let label, !label.isEmpty { parts.append(label) }
        if let value, !value.isEmpty { parts.append(value) }
        let spokenTraits = traits.filter {
            ["button", "header", "link", "image", "adjustable", "selected", "searchField", "tabBar", "disabled"].contains($0)
        }
        if !spokenTraits.isEmpty { parts.append(spokenTraits.joined(separator: ", ")) }
        if let hint, !hint.isEmpty { parts.append(hint) }
        return parts.isEmpty ? "(no accessibility content)" : parts.joined(separator: ". ")
    }
}

/// One node of the view hierarchy as it relates to accessibility: containers
/// (windows, scroll views, stacks…) with the accessibility elements they hold
/// as leaves. Mirrors what Xcode's view debugger shows, pruned to branches
/// that carry accessible content.
public struct AccessibilityTreeNode: Codable, Equatable, Sendable {
    /// Cleaned-up view class name ("UIScrollView", "UIHostingView"…).
    public var className: String
    /// The node's frame in screen coordinates, in points.
    public var frame: CGRect
    /// Index into `MeasurementSnapshot.accessibilityElements` when this node
    /// is an accessibility element (a leaf); nil for pure containers.
    public var elementIndex: Int?
    /// Extra identity when known — "SF Symbol · gear" or "Asset · logo" for
    /// UIImageView-backed images. Nil for content with no public identity.
    public var detail: String?
    public var children: [AccessibilityTreeNode]

    public init(
        className: String,
        frame: CGRect,
        elementIndex: Int? = nil,
        detail: String? = nil,
        children: [AccessibilityTreeNode] = []
    ) {
        self.className = className
        self.frame = frame
        self.elementIndex = elementIndex
        self.detail = detail
        self.children = children
    }
}

#if canImport(UIKit)
/// Walks the app's own accessibility tree — the same public protocol
/// VoiceOver uses — collecting the elements in approximate reading order,
/// plus the container hierarchy they live in (for the Xcode-style tree).
enum AccessibilitySnapshotter {
    static func collect() -> (elements: [AccessibilityElementInfo], tree: [AccessibilityTreeNode]) {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        // Right after launch no window is key yet; fall back to any visible
        // window so early snapshots still carry the tree.
        guard let window = windows.first(where: { $0.isKeyWindow })
            ?? windows.first(where: { !$0.isHidden }) else { return ([], []) }
        var result: [AccessibilityElementInfo] = []
        var tree = walk(window, into: &result, depth: 0)
        // The walk yields hierarchy order, which puts late siblings like the
        // navigation bar (the screen title!) after the content. VoiceOver
        // reads spatially — top-to-bottom, left-to-right — so re-sort the
        // flat list and remap the tree's element indices to match.
        let order = readingOrder(of: result)
        if order != Array(result.indices) {
            var newIndexByOld = [Int](repeating: 0, count: order.count)
            for (newIndex, oldIndex) in order.enumerated() {
                newIndexByOld[oldIndex] = newIndex
            }
            result = order.map { result[$0] }
            tree = remap(tree, newIndexByOld: newIndexByOld)
        }
        // Note: iOS builds the accessibility tree lazily, only while the
        // system accessibility flag is on (VoiceOver, Accessibility
        // Inspector, UI tests — or, in the simulator, the
        // com.apple.Accessibility defaults the companion can write).
        // Without it this walk legitimately finds nothing.
        return (result, tree)
    }

    /// Approximates VoiceOver's sweep: rows are built by vertical overlap
    /// (an element joins the current row while its center falls inside the
    /// row's band), then each row reads left to right.
    private static func readingOrder(of elements: [AccessibilityElementInfo]) -> [Int] {
        let byY = elements.indices.sorted {
            (elements[$0].frame.minY, elements[$0].frame.minX)
                < (elements[$1].frame.minY, elements[$1].frame.minX)
        }
        var rows: [[Int]] = []
        var currentRow: [Int] = []
        var rowMaxY: CGFloat = -.greatestFiniteMagnitude
        for index in byY {
            let frame = elements[index].frame
            if currentRow.isEmpty || frame.midY < rowMaxY {
                currentRow.append(index)
                rowMaxY = max(rowMaxY, frame.maxY)
            } else {
                rows.append(currentRow)
                currentRow = [index]
                rowMaxY = frame.maxY
            }
        }
        if !currentRow.isEmpty { rows.append(currentRow) }
        return rows.flatMap { row in
            row.sorted { elements[$0].frame.minX < elements[$1].frame.minX }
        }
    }

    private static func remap(
        _ nodes: [AccessibilityTreeNode],
        newIndexByOld: [Int]
    ) -> [AccessibilityTreeNode] {
        nodes.map { node in
            var node = node
            if let old = node.elementIndex, newIndexByOld.indices.contains(old) {
                node.elementIndex = newIndexByOld[old]
            }
            node.children = remap(node.children, newIndexByOld: newIndexByOld)
            return node
        }
    }

    private static func walk(
        _ node: NSObject,
        into result: inout [AccessibilityElementInfo],
        depth: Int
    ) -> [AccessibilityTreeNode] {
        guard depth < 80, result.count < 400 else { return [] }

        if let view = node as? UIView {
            if view.isHidden || view.alpha < 0.01 || view.accessibilityElementsHidden {
                return []
            }
        }

        if node.isAccessibilityElement {
            let frame = node.accessibilityFrame
            guard frame.width > 0.5, frame.height > 0.5 else { return [] }
            result.append(
                AccessibilityElementInfo(
                    label: node.accessibilityLabel,
                    value: node.accessibilityValue,
                    hint: node.accessibilityHint,
                    identifier: (node as? UIAccessibilityIdentification)?.accessibilityIdentifier,
                    traits: traitNames(node.accessibilityTraits),
                    frame: frame
                )
            )
            // A merged element (a SwiftUI row combining image + texts) still
            // has visual subviews — keep them as children so the nested
            // content stays selectable even though VoiceOver flattens it.
            let children = (node as? UIView).map { visualChildren(of: $0, depth: 0) } ?? []
            return [
                AccessibilityTreeNode(
                    className: cleanClassName(of: node),
                    frame: frame,
                    elementIndex: result.count - 1,
                    detail: (node as? UIImageView).flatMap(imageIdentity),
                    children: children
                )
            ]
        }

        var childNodes: [AccessibilityTreeNode] = []
        if let elements = node.accessibilityElements?.compactMap({ $0 as? NSObject }), !elements.isEmpty {
            for element in elements {
                childNodes += walk(element, into: &result, depth: depth + 1)
            }
            // SwiftUI keeps the drawing views (each Text/Image) beside the
            // accessibility elements, not inside them — nest each one under
            // the element whose frame contains it.
            if let view = node as? UIView {
                adopt(visualChildren(of: view, depth: 0), into: &childNodes)
            }
        } else if let view = node as? UIView {
            for subview in view.subviews {
                childNodes += walk(subview, into: &result, depth: depth + 1)
            }
        }

        // Prune branches with no accessible content, and collapse the deep
        // single-child wrapper chains SwiftUI hosts views in — otherwise the
        // tree is dominated by private plumbing instead of structure.
        guard !childNodes.isEmpty else { return [] }
        let name = cleanClassName(of: node)
        if childNodes.count == 1, !isStructuralClass(name) {
            return childNodes
        }

        let frame: CGRect
        if let view = node as? UIView {
            frame = UIAccessibility.convertToScreenCoordinates(view.bounds, in: view)
        } else {
            frame = childNodes.dropFirst().reduce(childNodes[0].frame) { $0.union($1.frame) }
        }
        return [
            AccessibilityTreeNode(
                className: name,
                frame: frame,
                children: childNodes
            )
        ]
    }

    /// Collects the visible drawing content (rendered Text/Image) under
    /// `view`, skipping accessibility elements (the main walk owns those)
    /// and collapsing plain wrappers. SwiftUI renders most content as
    /// CALayers rather than views, so this descends into sublayers too.
    /// These become selectable children of merged elements.
    private static func visualChildren(of view: UIView, depth: Int) -> [AccessibilityTreeNode] {
        guard depth < 12 else { return [] }
        // SwiftUI draws row backgrounds and texts as sublayers attached
        // directly to a container's layer, beside the subviews — collect
        // both. Subview backing layers are skipped inside layerNodes.
        var nodes: [AccessibilityTreeNode] = layerNodes(of: view.layer, in: view, depth: 0)
        for subview in view.subviews {
            if subview.isHidden || subview.alpha < 0.01 || subview.isAccessibilityElement {
                continue
            }
            let frame = UIAccessibility.convertToScreenCoordinates(subview.bounds, in: subview)
            guard frame.width > 1, frame.height > 1 else { continue }
            let name = cleanClassName(of: subview)

            let children = visualChildren(of: subview, depth: depth + 1)
            if children.isEmpty {
                if subview.subviews.isEmpty,
                   subview.layer.contents != nil || subview is UIImageView || subview is UILabel {
                    nodes.append(
                        AccessibilityTreeNode(
                            className: name,
                            frame: frame,
                            detail: (subview as? UIImageView).flatMap(imageIdentity)
                        )
                    )
                }
                continue
            }
            if children.count == 1, !isStructuralClass(name) {
                nodes += children
            } else {
                nodes.append(
                    AccessibilityTreeNode(className: name, frame: frame, children: children)
                )
            }
        }
        return nodes
    }

    /// Rendered CALayers under `layer`: each sublayer with bitmap/gradient/
    /// shape content becomes a node, positioned via the hosting view.
    /// Subview backing layers are excluded — the view walk owns those.
    private static func layerNodes(of layer: CALayer, in view: UIView, depth: Int) -> [AccessibilityTreeNode] {
        guard depth < 8 else { return [] }
        var nodes: [AccessibilityTreeNode] = []
        for sublayer in layer.sublayers ?? [] {
            if sublayer.isHidden || sublayer.opacity < 0.01 { continue }
            if sublayer.delegate is UIView { continue }
            let rectInView = sublayer.convert(sublayer.bounds, to: view.layer)
            let frame = UIAccessibility.convertToScreenCoordinates(rectInView, in: view)
            guard frame.width > 1, frame.height > 1 else { continue }

            let children = layerNodes(of: sublayer, in: view, depth: depth + 1)
            let hasContent = sublayer.contents != nil
                || sublayer is CAGradientLayer
                || sublayer is CAShapeLayer
                || sublayer is CATextLayer
            if !children.isEmpty {
                if children.count == 1 {
                    nodes += children
                } else {
                    nodes.append(
                        AccessibilityTreeNode(className: layerName(sublayer), frame: frame, children: children)
                    )
                }
            } else if hasContent {
                nodes.append(
                    AccessibilityTreeNode(className: layerName(sublayer), frame: frame)
                )
            }
        }
        return nodes
    }

    /// The image's origin when the system still knows it: SF Symbol name or
    /// asset-catalog name, parsed from UIImage's description ("symbol(system:
    /// gear)" / "named(main: logo)"). SwiftUI-drawn images render as bare
    /// CGImages and keep no identity — those return nil.
    private static func imageIdentity(_ imageView: UIImageView) -> String? {
        guard let image = imageView.image else { return nil }
        let description = image.description
        if let value = Self.capture(after: "symbol(system: ", in: description) {
            return "SF Symbol · \(value)"
        }
        if let value = Self.capture(after: "symbol(", in: description) {
            return "Symbol · \(value)"
        }
        if let value = Self.capture(after: "named(main: ", in: description) {
            return "Asset · \(value)"
        }
        if let value = Self.capture(after: "named(", in: description) {
            return "Asset · \(value)"
        }
        return image.isSymbolImage ? "SF Symbol" : nil
    }

    private static func capture(after prefix: String, in text: String) -> String? {
        guard let range = text.range(of: prefix) else { return nil }
        let rest = text[range.upperBound...]
        guard let end = rest.firstIndex(where: { $0 == ")" || $0 == "," }) else { return nil }
        let value = String(rest[..<end]).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    private static func layerName(_ layer: CALayer) -> String {
        let name = cleanClassName(of: layer)
        return name == "CALayer" ? "Layer" : name
    }

    /// Nests every visual LEAF under the deepest tree node containing its
    /// center — elements live at varying depths (SwiftUI draws whole stacks
    /// into one view beside them), so the insertion recurses; parentless
    /// leaves stay at this level.
    private static func adopt(
        _ visuals: [AccessibilityTreeNode],
        into nodes: inout [AccessibilityTreeNode]
    ) {
        for leaf in flattenLeaves(visuals) {
            if !insert(leaf, into: &nodes) {
                nodes.append(leaf)
            }
        }
    }

    private static func flattenLeaves(_ nodes: [AccessibilityTreeNode]) -> [AccessibilityTreeNode] {
        nodes.flatMap { $0.children.isEmpty ? [$0] : flattenLeaves($0.children) }
    }

    /// Places `leaf` under the smallest node overlapping most of it,
    /// descending as deep as possible. Overlap (≥half the leaf) instead of
    /// strict containment keeps scrolled-out content attached to its element
    /// (a carousel card half outside the viewport still owns its layers).
    /// Visual leaves never receive children of their own.
    private static func insert(
        _ leaf: AccessibilityTreeNode,
        into nodes: inout [AccessibilityTreeNode]
    ) -> Bool {
        let leafArea = max(leaf.frame.width * leaf.frame.height, 1)
        var bestIndex: Int?
        var bestArea = CGFloat.greatestFiniteMagnitude
        for (index, node) in nodes.enumerated() {
            // Only elements and containers can host content — not leaves.
            guard node.elementIndex != nil || !node.children.isEmpty else { continue }
            let overlap = node.frame.intersection(leaf.frame)
            guard !overlap.isNull, overlap.width * overlap.height >= leafArea * 0.5 else { continue }
            let area = node.frame.width * node.frame.height
            if area < bestArea {
                bestArea = area
                bestIndex = index
            }
        }
        guard let bestIndex else { return false }
        if !insert(leaf, into: &nodes[bestIndex].children) {
            nodes[bestIndex].children.append(leaf)
        }
        return true
    }

    /// "_UIHostingView<ModifiedContent<…>>" → "UIHostingView".
    private static func cleanClassName(of object: NSObject) -> String {
        var name = String(describing: type(of: object))
        if let generic = name.firstIndex(of: "<") {
            name = String(name[..<generic])
        }
        while name.hasPrefix("_") { name.removeFirst() }
        return name.isEmpty ? "View" : name
    }

    /// Container classes worth keeping even when they wrap a single child.
    private static func isStructuralClass(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return ["window", "scroll", "stack", "table", "collection", "cell", "hosting", "navigation", "tab", "bar", "page"]
            .contains { lowered.contains($0) }
    }

    private static func traitNames(_ traits: UIAccessibilityTraits) -> [String] {
        let mapping: [(UIAccessibilityTraits, String)] = [
            (.button, "button"),
            (.header, "header"),
            (.link, "link"),
            (.image, "image"),
            (.staticText, "staticText"),
            (.searchField, "searchField"),
            (.selected, "selected"),
            (.adjustable, "adjustable"),
            (.notEnabled, "disabled"),
            (.keyboardKey, "keyboardKey"),
            (.summaryElement, "summary"),
            (.updatesFrequently, "updatesFrequently"),
            (.startsMediaSession, "startsMedia"),
            (.playsSound, "playsSound"),
            (.allowsDirectInteraction, "directInteraction"),
            (.causesPageTurn, "pageTurn"),
            (.tabBar, "tabBar"),
        ]
        return mapping.filter { traits.contains($0.0) }.map(\.1)
    }
}
#endif
