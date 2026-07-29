import SwiftUI

/// Shared visual constants for the measurement overlay.
enum OverlayStyle {
    static let labelFont = Font.system(size: 9, weight: .medium, design: .monospaced)
    static let validColor = Color.green
    static let invalidColor = Color.red
    static let neutralColor = Color.secondary
    static let gridColor = Color.blue.opacity(0.12)
    static let safeAreaColor = Color.orange.opacity(0.7)
    static let selectionColor = Color.yellow

    static func color(for role: MeasurementRole) -> Color {
        switch role {
        case .container: return .blue
        case .content: return .green
        case .title: return .purple
        case .subtitle: return .teal
        case .icon: return .orange
        case .image: return .pink
        case .background: return .gray
        case .custom: return .indigo
        }
    }

    /// Formats a point value for display, dropping the fraction (values are
    /// rounded to whole points before display).
    static func points(_ value: CGFloat) -> String {
        String(Int(value.rounded()))
    }

    /// Text and color for a spacing/padding value, applying token validation
    /// when enabled. Invalid values show the nearest token, e.g. "13→12".
    static func validated(
        _ value: CGFloat,
        configuration: MeasureConfiguration,
        prefix: String = ""
    ) -> (text: String, color: Color) {
        let rounded = value.rounded()
        guard configuration.validatesTokens else {
            return (prefix + points(rounded), neutralColor)
        }
        let validation = SpacingTokenValidator.validate(rounded, tokens: configuration.spacingTokens)
        if validation.isValid {
            return (prefix + points(rounded), validColor)
        }
        if let nearest = validation.nearestToken {
            return (prefix + points(rounded) + "→" + points(nearest), invalidColor)
        }
        return (prefix + points(rounded), neutralColor)
    }

    /// Approximate rendered size of an `OverlayLabel`, used for collision
    /// resolution before layout. 9pt monospaced ≈ 5.6pt per glyph + padding.
    static func estimatedLabelSize(for text: String) -> CGSize {
        CGSize(width: CGFloat(text.count) * 5.6 + 8, height: 13)
    }
}

/// A small readable label used for sizes, padding, and spacing values.
struct OverlayLabel: View {
    let text: String
    var color: Color = OverlayStyle.neutralColor

    var body: some View {
        Text(text)
            .font(OverlayStyle.labelFont)
            .foregroundColor(.white)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(color.opacity(0.85), in: RoundedRectangle(cornerRadius: 3))
            .fixedSize()
    }
}
