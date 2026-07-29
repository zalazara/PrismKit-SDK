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
            toggleButton
        }
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
            row("Bounds", isOn: $configuration.showsBounds)
            row("Sizes", isOn: $configuration.showsSizeLabels)
            row("Padding", isOn: $configuration.showsInternalPadding)
            row("Spacing", isOn: $configuration.showsExternalSpacing)
            row("Grid", isOn: $configuration.showsGrid)
            row("Safe area", isOn: $configuration.showsSafeArea)
            row("Tokens", isOn: $configuration.validatesTokens)
            Divider()
            row("Selection", isOn: $isSelectionEnabled)
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

    private func row(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
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
