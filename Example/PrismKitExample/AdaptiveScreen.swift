import PrismKit
import SwiftUI

/// The screen the App preview controls are for.
///
/// The shop screens deliberately hard-code their type and colour: they are
/// compared against `Example.pen` numerically, and text that resizes with the
/// reader's settings would move every frame below it and report defects the
/// design never asked for. That makes them the wrong place to show what
/// Dynamic Type and appearance do.
///
/// So this screen is built the other way: text styles, semantic colours, and
/// two rows that are wrong on purpose. Turn the text size up from the Mac and
/// the top half reflows while the bottom half breaks — which is the whole
/// reason to have the control.
struct AdaptiveScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                section(
                    "Reflows correctly",
                    footnote: "Text styles, and heights that follow their content."
                ) {
                    goodRow(
                        icon: "checkmark.seal.fill",
                        title: "Order confirmed",
                        detail: "Arriving Thursday between 9am and 1pm",
                        id: "adaptive-good-order"
                    )
                    goodRow(
                        icon: "creditcard.fill",
                        title: "Visa ending 4242",
                        detail: "Charged $249.00 on 12 March",
                        id: "adaptive-good-card"
                    )
                }

                section(
                    "Breaks at larger sizes",
                    footnote: "A fixed 44 pt row and a one-line label. Raise the text size and watch."
                ) {
                    brokenRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "Confirm your delivery address",
                        id: "adaptive-broken-address"
                    )
                    brokenRow(
                        icon: "clock.fill",
                        title: "Held for another 15 minutes",
                        id: "adaptive-broken-hold"
                    )
                }

                contrastCard
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .measureScope()
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Adaptive")
                .font(.largeTitle.weight(.bold))
                .designNode("adaptive-title")
            // Reading the current settings back is the quickest way to see that
            // the control on the Mac reached this process at all.
            Text("\(sizeCategory.label) · \(colorScheme == .dark ? "Dark" : "Light")")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .designNode("adaptive-state")
        }
    }

    private func section(
        _ title: String,
        footnote: String,
        @ViewBuilder rows: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            VStack(spacing: 0) {
                rows()
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(footnote)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Text styles and a height that comes from the content, so every size
    /// category lays out.
    private func goodRow(icon: String, title: String, detail: String, id: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .designNode(id)
    }

    /// Wrong on purpose, in the two ways a layout usually fails: a fixed height
    /// the text outgrows, and a line limit that turns a sentence into an
    /// ellipsis. Both look fine at the default size.
    private func brokenRow(icon: String, title: String, id: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundColor(.orange)
            Text(title)
                .font(.system(size: 15))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .designNode(id)
    }

    /// A hard-coded pair that ignores the appearance, next to a semantic pair
    /// that follows it. Switching the Mac control moves one card and not the
    /// other.
    private var contrastCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Colour")
                .font(.headline)
            HStack(spacing: 12) {
                swatch(
                    "Semantic",
                    background: Color(uiColor: .secondarySystemGroupedBackground),
                    foreground: Color(uiColor: .label),
                    id: "adaptive-swatch-semantic"
                )
                swatch(
                    "Hard-coded",
                    background: Color(red: 1, green: 1, blue: 1),
                    foreground: Color(red: 0.11, green: 0.11, blue: 0.12),
                    id: "adaptive-swatch-fixed"
                )
            }
            Text("The right card keeps its light palette in dark mode, because it names its colours instead of asking the system.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func swatch(
        _ title: String,
        background: Color,
        foreground: Color,
        id: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text("Aa")
                .font(.title2)
        }
        .foregroundColor(foreground)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .designNode(id)
    }
}

private extension ContentSizeCategory {
    /// The iOS-style abbreviation, so the header can say which size is in force.
    var label: String {
        switch self {
        case .extraSmall: return "XS"
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        case .extraLarge: return "XL"
        case .extraExtraLarge: return "XXL"
        case .extraExtraExtraLarge: return "XXXL"
        case .accessibilityMedium: return "AX1"
        case .accessibilityLarge: return "AX2"
        case .accessibilityExtraLarge: return "AX3"
        case .accessibilityExtraExtraLarge: return "AX4"
        case .accessibilityExtraExtraExtraLarge: return "AX5"
        @unknown default: return "?"
        }
    }
}
