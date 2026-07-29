import SwiftUI

/// The composed measurement overlay: grid, safe area, bounds, labels, and the
/// optional selection layer.
///
/// Focus mode: while selection mode is active and something is selected, only
/// the selected components (their whole group) render visuals — the rest of
/// the overlay gets out of the way. Tap targets remain on every measurement so
/// the selection can still be changed.
struct MeasureOverlayView: View {
    let measurements: [ResolvedMeasurement]
    let configuration: MeasureConfiguration
    let safeAreaInsets: EdgeInsets
    let size: CGSize
    let selection: Binding<MeasurementSelection>?

    var body: some View {
        ZStack(alignment: .topLeading) {
            visualLayers
                .allowsHitTesting(false)
            if let selection {
                SelectionLayerView(
                    measurements: measurements,
                    configuration: configuration,
                    size: size,
                    selection: selection
                )
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        // The debug overlay must not pollute the app's accessibility tree —
        // neither for assistive technologies nor for the a11y snapshotter.
        .accessibilityHidden(true)
    }

    /// Measurements whose visuals are drawn: everything, or — when something
    /// is selected — only the groups the selection belongs to.
    private var focusedMeasurements: [ResolvedMeasurement] {
        guard let selection = selection?.wrappedValue, !selection.isEmpty else {
            return measurements
        }
        let selectedGroups = Set(
            measurements.filter { selection.contains($0.id) }.map(\.group)
        )
        return measurements.filter { selectedGroups.contains($0.group) }
    }

    @ViewBuilder
    private var visualLayers: some View {
        if configuration.showsGrid {
            GridOverlayView(gridSize: configuration.gridSize)
        }
        if configuration.showsSafeArea {
            SafeAreaOverlayView(size: size, insets: safeAreaInsets)
        }
        if configuration.showsBounds {
            ForEach(focusedMeasurements) { measurement in
                BoundsMarkerView(
                    measurement: measurement,
                    isSelected: selection?.wrappedValue.contains(measurement.id) ?? false
                )
            }
        }
        LabelLayer(measurements: focusedMeasurements, configuration: configuration)
    }
}
