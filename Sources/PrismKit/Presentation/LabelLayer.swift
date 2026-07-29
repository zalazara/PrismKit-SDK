import SwiftUI

/// One label the overlay wants to draw, before collision resolution.
struct OverlayLabelItem: Identifiable {
    let id: String
    let text: String
    let color: Color
    let preferredCenter: CGPoint

    var estimatedRect: CGRect {
        let size = OverlayStyle.estimatedLabelSize(for: text)
        return CGRect(
            x: preferredCenter.x - size.width / 2,
            y: preferredCenter.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

/// Renders all size and padding labels in one pass, running them through
/// `LabelLayoutSolver` so clustered labels stack instead of overlapping.
struct LabelLayer: View {
    let measurements: [ResolvedMeasurement]
    let configuration: MeasureConfiguration

    var body: some View {
        let items = buildItems()
        let positions = LabelLayoutSolver.resolve(
            items.map { LabelCandidate(id: $0.id, rect: $0.estimatedRect) }
        )

        // Leader lines connect displaced labels back to their anchor point so
        // stacked labels stay attributable to their element.
        Path { path in
            for item in items {
                guard let position = positions[item.id] else { continue }
                let dx = position.x - item.preferredCenter.x
                let dy = position.y - item.preferredCenter.y
                if abs(dx) + abs(dy) > 10 {
                    path.move(to: position)
                    path.addLine(to: item.preferredCenter)
                }
            }
        }
        .stroke(Color.secondary.opacity(0.4), lineWidth: 0.5)

        ForEach(items) { item in
            OverlayLabel(text: item.text, color: item.color)
                .position(positions[item.id] ?? item.preferredCenter)
        }
    }

    private func buildItems() -> [OverlayLabelItem] {
        var items: [OverlayLabelItem] = []

        if configuration.showsSizeLabels {
            for measurement in measurements {
                let frame = measurement.frame
                let name = measurement.role == .container
                    ? measurement.group
                    : "\(measurement.group).\(measurement.role.label)"
                let text = "\(name) \(OverlayStyle.points(frame.width))×\(OverlayStyle.points(frame.height))"
                // Sit just above the frame when there is room, otherwise inside it.
                let y = frame.minY > 14 ? frame.minY - 7 : frame.minY + 7
                items.append(
                    OverlayLabelItem(
                        id: "size:\(measurement.id)",
                        text: text,
                        color: OverlayStyle.color(for: measurement.role),
                        preferredCenter: CGPoint(x: frame.midX, y: y)
                    )
                )
            }
        }

        if configuration.showsInternalPadding {
            for group in MeasurementGroup.groups(from: measurements) {
                guard let container = group.container?.frame,
                      let content = group.contentUnionFrame,
                      let padding = group.contentPadding?.rounded() else { continue }
                let edges: [(edge: String, value: CGFloat, center: CGPoint)] = [
                    ("top", padding.top, CGPoint(x: content.midX, y: (container.minY + content.minY) / 2)),
                    ("bottom", padding.bottom, CGPoint(x: content.midX, y: (container.maxY + content.maxY) / 2)),
                    ("leading", padding.leading, CGPoint(x: (container.minX + content.minX) / 2, y: content.midY)),
                    ("trailing", padding.trailing, CGPoint(x: (container.maxX + content.maxX) / 2, y: content.midY)),
                ]
                // A zero edge has no visible gap to annotate; skip it to reduce noise.
                for (edge, value, center) in edges where value != 0 {
                    let (text, color) = OverlayStyle.validated(value, configuration: configuration)
                    items.append(
                        OverlayLabelItem(
                            id: "pad:\(group.name):\(edge)",
                            text: text,
                            color: color,
                            preferredCenter: center
                        )
                    )
                }
            }
        }

        return items
    }
}
