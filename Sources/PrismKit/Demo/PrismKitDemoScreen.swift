import SwiftUI

// Sample UI: useful while developing against PrismKit, dead weight in a
// shipping binary.
#if DEBUG

/// A demo screen proving the measurement workflow end to end: a title, a card,
/// a button, a list row, and nested padding — all instrumented, with bounds,
/// size labels, internal padding, grid, safe area, and token validation.
///
/// Present it directly, or open the `PrismKitDemoScreen` preview.
public struct PrismKitDemoScreen: View {
    private let configuration: MeasureConfiguration
    private let isSelectionEnabled: Bool

    public init(
        configuration: MeasureConfiguration = MeasureConfiguration(
            showsGrid: true,
            showsSafeArea: true
        ),
        selection: Bool = false
    ) {
        self.configuration = configuration
        self.isSelectionEnabled = selection
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Design QA Demo")
                .font(.title2.bold())
                .measure("screenTitle", role: .title)

            demoCard

            demoButton

            demoListRow

            nestedPadding

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .measureScope(configuration: configuration, selection: isSelectionEnabled)
    }

    private var demoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Card title")
                .font(.headline)
                .measure("card", role: .title)
            Text("Supporting description that wraps inside the card content area.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .measure("card", role: .content)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
        )
        .measure("card", role: .container)
    }

    private var demoButton: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .measure("primaryButton", role: .icon)
            Text("Confirm")
                .font(.callout.weight(.semibold))
        }
        .foregroundColor(.white)
        .measure("primaryButton", role: .content)
        .padding(.horizontal, 20)
        .padding(.vertical, 13) // Deliberately off-token: validation flags 13 → 12.
        .background(Capsule().fill(Color.blue))
        .measure("primaryButton", role: .container)
    }

    private var demoListRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.title2)
                .measure("listRow", role: .icon)
            VStack(alignment: .leading, spacing: 2) {
                Text("Row title")
                    .font(.body)
                    .measure("listRow", role: .title)
                Text("Row subtitle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .measure("listRow", role: .subtitle)
            }
        }
        .measure("listRow", role: .content)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.gray.opacity(0.3))
        )
        .measure("listRow", role: .container)
    }

    private var nestedPadding: some View {
        Text("Nested")
            .font(.footnote)
            .measure("nested", role: .content)
            .padding(8)
            .background(Color.blue.opacity(0.15))
            .measure("nested", role: .container)
            .measure("nestedOuter", role: .content)
            .padding(16)
            .background(Color.blue.opacity(0.08))
            .measure("nestedOuter", role: .container)
    }
}

struct PrismKitDemoScreen_Previews: PreviewProvider {
    static var previews: some View {
        PrismKitDemoScreen()
            .previewDisplayName("Static overlay")

        PrismKitDemoScreen(selection: true)
            .previewDisplayName("Selection mode")

        PrismKitDemoScreen(
            configuration: MeasureConfiguration(showsGrid: false, showsSafeArea: false)
        )
        .previewDisplayName("Bounds and padding only")
    }
}

#endif
