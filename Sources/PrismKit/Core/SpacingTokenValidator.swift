import CoreGraphics

/// The result of validating a spacing or padding value against design-system tokens.
public struct TokenValidation: Equatable, Sendable {
    /// The raw value that was validated, in points.
    public let value: CGFloat

    /// Whether the value (rounded to whole points) matches a token exactly.
    public let isValid: Bool

    /// The closest token to the value, or `nil` when no tokens are configured.
    public let nearestToken: CGFloat?

    /// Rounded value minus the nearest token, or `nil` when no tokens are configured.
    public let difference: CGFloat?

    public init(value: CGFloat, isValid: Bool, nearestToken: CGFloat?, difference: CGFloat?) {
        self.value = value
        self.isValid = isValid
        self.nearestToken = nearestToken
        self.difference = difference
    }
}

/// Validates spacing values against a configured token list using
/// rounded-point comparison.
public enum SpacingTokenValidator {
    /// Validates `value` against `tokens`.
    ///
    /// The value is rounded to whole points before comparison. When two tokens
    /// are equally close, the one listed first wins. An empty token list yields
    /// an invalid result with no nearest token.
    public static func validate(_ value: CGFloat, tokens: [CGFloat]) -> TokenValidation {
        guard !tokens.isEmpty else {
            return TokenValidation(value: value, isValid: false, nearestToken: nil, difference: nil)
        }
        let rounded = value.rounded()
        var nearest = tokens[0]
        for token in tokens.dropFirst() where abs(token - rounded) < abs(nearest - rounded) {
            nearest = token
        }
        let difference = rounded - nearest
        return TokenValidation(
            value: value,
            isValid: difference == 0,
            nearestToken: nearest,
            difference: difference
        )
    }
}
