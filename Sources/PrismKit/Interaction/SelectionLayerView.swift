import SwiftUI

/// Tap targets over measured frames plus the distance readouts for the current
/// selection: one selected element shows its distances to the scope edges, two
/// selected elements show the spacing between them.
/// Only mounted when selection mode is enabled.
struct SelectionLayerView: View {
    let measurements: [ResolvedMeasurement]
    let configuration: MeasureConfiguration
    let size: CGSize
    @Binding var selection: MeasurementSelection

    var body: some View {
        ForEach(measurements) { measurement in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(
                    width: max(1, measurement.frame.width),
                    height: max(1, measurement.frame.height)
                )
                .position(x: measurement.frame.midX, y: measurement.frame.midY)
                .onTapGesture { selection.toggle(measurement.id) }
        }

        if configuration.showsExternalSpacing {
            let selected = measurements.filter { selection.contains($0.id) }
            if selected.count == 1 {
                EdgeDistancesView(measurement: selected[0], size: size, configuration: configuration)
            } else if selected.count > 1 {
                // Distances between geometry-adjacent selected elements.
                let ordered = selected.sorted {
                    ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX)
                }
                ForEach(Array(zip(ordered, ordered.dropFirst())), id: \.0.id) { first, second in
                    ExternalSpacingView(first: first, second: second, configuration: configuration)
                }
            }
        }
    }
}

/// Guide lines and distances from a selected element's edges to the scope
/// bounds (the screen edges when the scope covers the whole screen).
struct EdgeDistancesView: View {
    let measurement: ResolvedMeasurement
    let size: CGSize
    let configuration: MeasureConfiguration

    var body: some View {
        let frame = measurement.frame
        let bounds = CGRect(origin: .zero, size: size)
        let distances = InternalPadding.between(container: bounds, content: frame).rounded()

        Path { path in
            path.move(to: CGPoint(x: frame.midX, y: 0))
            path.addLine(to: CGPoint(x: frame.midX, y: frame.minY))
            path.move(to: CGPoint(x: frame.midX, y: frame.maxY))
            path.addLine(to: CGPoint(x: frame.midX, y: size.height))
            path.move(to: CGPoint(x: 0, y: frame.midY))
            path.addLine(to: CGPoint(x: frame.minX, y: frame.midY))
            path.move(to: CGPoint(x: frame.maxX, y: frame.midY))
            path.addLine(to: CGPoint(x: size.width, y: frame.midY))
        }
        .stroke(
            OverlayStyle.selectionColor.opacity(0.6),
            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
        )

        distanceLabel(distances.top, at: CGPoint(x: frame.midX, y: frame.minY / 2))
        distanceLabel(distances.bottom, at: CGPoint(x: frame.midX, y: (frame.maxY + size.height) / 2))
        distanceLabel(distances.leading, at: CGPoint(x: frame.minX / 2, y: frame.midY))
        distanceLabel(distances.trailing, at: CGPoint(x: (frame.maxX + size.width) / 2, y: frame.midY))
    }

    @ViewBuilder
    private func distanceLabel(_ value: CGFloat, at point: CGPoint) -> some View {
        if value > 0 {
            let (text, color) = OverlayStyle.validated(value, configuration: configuration)
            OverlayLabel(text: text, color: color)
                .position(point)
        }
    }
}

/// A line between two selected frames with their horizontal and vertical gaps.
struct ExternalSpacingView: View {
    let first: ResolvedMeasurement
    let second: ResolvedMeasurement
    let configuration: MeasureConfiguration

    var body: some View {
        let spacing = ExternalSpacing.between(first.frame, second.frame).rounded()
        let firstCenter = CGPoint(x: first.frame.midX, y: first.frame.midY)
        let secondCenter = CGPoint(x: second.frame.midX, y: second.frame.midY)
        let midpoint = CGPoint(
            x: (firstCenter.x + secondCenter.x) / 2,
            y: (firstCenter.y + secondCenter.y) / 2
        )
        let horizontal = OverlayStyle.validated(spacing.horizontal, configuration: configuration, prefix: "H ")
        let vertical = OverlayStyle.validated(spacing.vertical, configuration: configuration, prefix: "V ")

        Path { path in
            path.move(to: firstCenter)
            path.addLine(to: secondCenter)
        }
        .stroke(OverlayStyle.selectionColor, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        VStack(spacing: 2) {
            OverlayLabel(text: horizontal.text, color: horizontal.color)
            OverlayLabel(text: vertical.text, color: vertical.color)
        }
        .position(midpoint)
    }
}
