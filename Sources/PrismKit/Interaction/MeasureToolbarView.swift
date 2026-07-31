import SwiftUI

/// A floating toolbar for configuring the overlay at runtime: collapsed it is
/// a single round button that never hides the screen; expanded it offers
/// toggles for every overlay layer, selection mode, and clearing the selection.
struct MeasureToolbarView: View {
    @Binding var configuration: MeasureConfiguration
    @Binding var isSelectionEnabled: Bool
    @Binding var selection: MeasurementSelection

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if isExpanded {
                panel
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomTrailing)))
            }
            HStack(spacing: 8) {
                selectButton
                toggleButton
            }
        }
    }

    /// Selection, promoted out of the panel.
    ///
    /// It was a row among nine others, two taps inside a collapsed toolbar,
    /// and it is the answer to the commonest problem with a busy screen: too
    /// much drawn at once. Tapping one component and seeing only that one —
    /// and the distances to the next one you tap — is what people reach for,
    /// so it should not be the hardest thing to find.
    private var selectButton: some View {
        Button {
            isSelectionEnabled.toggle()
            if !isSelectionEnabled { selection.clear() }
        } label: {
            Image(systemName: isSelectionEnabled ? "cursorarrow.click.2" : "cursorarrow")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isSelectionEnabled ? .white : .primary)
                .frame(width: 40, height: 40)
                .background(
                    isSelectionEnabled ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.ultraThinMaterial),
                    in: Circle()
                )
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.15)))
        }
        .buttonStyle(.plain)
        // Turning it off clears the selection, because leaving elements
        // selected while nothing can be selected is a state with no way out.
        .accessibilityLabel(isSelectionEnabled ? "Stop selecting" : "Select components")
    }

    private var toggleButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { isExpanded.toggle() }
        } label: {
            Image(systemName: isExpanded ? "xmark" : "ruler")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 7) {
            // These four describe a component, so they draw for whatever is
            // selected and arm the selection when switched on — otherwise
            // turning one on with nothing selected looks like a broken switch.
            componentRow("Bounds", isOn: $configuration.showsBounds)
            componentRow("Sizes", isOn: $configuration.showsSizeLabels)
            componentRow("Padding", isOn: $configuration.showsInternalPadding)
            componentRow("Spacing", isOn: $configuration.showsExternalSpacing)
            // These two describe the screen, so they simply draw.
            row("Grid", isOn: $configuration.showsGrid)
            row("Safe area", isOn: $configuration.showsSafeArea)
            row("Tokens", isOn: $configuration.validatesTokens)
            Divider()
            row("Selection", isOn: $isSelectionEnabled)
            if isSelectionEnabled, selection.isEmpty, showsComponentLayer {
                // The layer is on and there is nothing for it to draw. Saying
                // so beats leaving somebody tapping a switch that appears
                // to do nothing.
                Text("Tap an element")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if !selection.isEmpty {
                Button {
                    selection.clear()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle")
                        Text("Clear selection")
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 132, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.15))
        )
    }

    /// Whether any layer that needs a selection is switched on.
    private var showsComponentLayer: Bool {
        configuration.showsBounds
            || configuration.showsSizeLabels
            || configuration.showsInternalPadding
            || configuration.showsExternalSpacing
    }

    /// A layer that draws about a component: switching it on also arms the
    /// selection, because a layer with nothing selected has nothing to draw.
    private func componentRow(_ title: String, isOn: Binding<Bool>) -> some View {
        row(title, isOn: isOn) {
            if isOn.wrappedValue { isSelectionEnabled = true }
        }
    }

    private func row(
        _ title: String,
        isOn: Binding<Bool>,
        onChange: @escaping () -> Void = {}
    ) -> some View {
        Button {
            isOn.wrappedValue.toggle()
            onChange()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .foregroundColor(isOn.wrappedValue ? .blue : .secondary)
                Text(title)
                    .foregroundColor(.primary)
                Spacer(minLength: 0)
            }
            .font(.caption)
        }
        .buttonStyle(.plain)
    }
}
