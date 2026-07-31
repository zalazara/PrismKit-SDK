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

    /// Measurements whose visuals are drawn: only the groups the selection
    /// belongs to, and nothing at all when nothing is selected.
    ///
    /// Turning a layer on used to light up every instrumented view on the
    /// screen. On the demo screen it was designed against that is a handful of
    /// boxes; on a real one it is fifty, and fifty dashed rectangles with
    /// their labels is not a measurement of anything — it is the screen made
    /// unreadable. The layers say *what* to show about a component; the
    /// selection says *which*. With nothing selected there is no which, so
    /// nothing is drawn.
    ///
    /// The grid and the safe area are not in here on purpose: they describe
    /// the screen rather than any component, so they have nothing to be
    /// selected about and stay on when switched on.
    private var focusedMeasurements: [ResolvedMeasurement] {
        guard let selection = selection?.wrappedValue, !selection.isEmpty else {
            return []
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
