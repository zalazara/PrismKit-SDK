import PrismKit
import SwiftUI

extension View {
    /// Names a view after the design node it renders.
    ///
    /// Both halves matter. `measure` puts the name in the snapshot's
    /// measurement groups, which is what the design check pairs on — that
    /// pairing is an identity, not a guess, and it is the difference between
    /// a report you can act on and one you have to audit. `accessibilityIdentifier`
    /// is for UI tests, and would be the pairing key too if SwiftUI surfaced
    /// it to the accessibility tree — it does not, so it cannot be relied on
    /// here.
    ///
    /// Apply it where the design's frame is: before padding modifiers, so the
    /// measured frame is the node's own.
    func designNode(_ name: String) -> some View {
        accessibilityIdentifier(name).measure(name)
    }
}

/// The design system, transcribed from the `foundations` frame of `Example.pen`.
///
/// Every value here is a literal design point read out of the design file, not
/// a judgement call — the demo compares the rendered screen against that file
/// numerically, so a token invented in code would show up as a defect that the
/// design never asked for.
///
/// Type sizes are fixed rather than Dynamic Type for the same reason: the
/// comparison is geometric, and text that resizes with the user's settings
/// would move every frame below it.
enum Shop {

    /// The spacing scale from `foundations-spacing`. Layout uses only these.
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    /// The radii from `foundations-radius`, named after what they belong to.
    enum Radius {
        static let thumbnail: CGFloat = 10
        static let pill: CGFloat = 12
        static let button: CGFloat = 14
        static let card: CGFloat = 16
    }

    /// The palette from `foundations-color`.
    enum Palette {
        static let primaryText = Color(hex: 0x1C1C1E)
        static let secondaryText = Color(hex: 0x8E8E93)
        static let brandBlue = Color(hex: 0x0A84FF)
        static let pillGreenBackground = Color(hex: 0xE8F8EE)
        static let pillGreenText = Color(hex: 0x1C7C4A)
        static let divider = Color(hex: 0xE5E5EA)
        static let cardWhite = Color(hex: 0xFFFFFF)
        static let screenBackground = Color(hex: 0xF2F2F7)
    }

    /// The type ramp from `foundations-type`.
    enum TypeStyle {
        static let screenTitle = Font.system(size: 22, weight: .semibold)
        static let sectionTitle = Font.system(size: 17, weight: .semibold)
        static let emphasizedRow = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 16, weight: .regular)
        static let price = Font.system(size: 16, weight: .medium)
        static let pillCaption = Font.system(size: 13, weight: .regular)
        static let legal = Font.system(size: 12, weight: .regular)
    }

    /// The horizontal margin every screen's content sits inside.
    static let screenMargin: CGFloat = 16

    /// Card padding, as `[vertical, horizontal]` in the design.
    static let cardPaddingVertical: CGFloat = Space.lg
    static let cardPaddingHorizontal: CGFloat = Space.xl

    /// Every primary button in the design is this size.
    static let buttonHeight: CGFloat = 52
}

extension Color {
    /// Builds a colour from the hex literals the design file states, so a
    /// reader can check a value against `foundations-color` at a glance.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Shared building blocks

/// A white card. The design uses identical geometry on every screen, so this
/// exists to keep them identical in code too.
struct ShopCard<Content: View>: View {
    var horizontalPadding: CGFloat = Shop.cardPaddingHorizontal
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Shop.cardPaddingVertical)
        .padding(.horizontal, horizontalPadding)
        .background(Shop.Palette.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: Shop.Radius.card, style: .continuous))
    }
}

/// The primary action button, identical on every screen in the design.
struct ShopPrimaryButton: View {
    let title: String
    var height: CGFloat = Shop.buttonHeight
    var identifier: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Shop.TypeStyle.emphasizedRow)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(Shop.Palette.brandBlue)
                .clipShape(RoundedRectangle(cornerRadius: Shop.Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .designNode(identifier)
    }
}

/// A product image: a gradient rectangle with an SF Symbol on it. The design
/// carries no bitmaps, so neither does the app.
struct ProductThumbnail: View {
    let product: Product
    let size: CGSize
    let glyphSize: CGFloat
    var identifier: String

    var body: some View {
        LinearGradient(
            colors: product.colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: size.width, height: size.height)
        .overlay(
            Image(systemName: product.symbol)
                .font(.system(size: glyphSize * 0.6, weight: .medium))
                .foregroundColor(.white)
                .frame(width: glyphSize, height: glyphSize)
                .designNode("\(identifier)-glyph")
        )
        .clipShape(RoundedRectangle(cornerRadius: Shop.Radius.thumbnail, style: .continuous))
        .designNode(identifier)
    }
}

/// A label/value row: the design repeats this shape in the specs, summary and
/// confirmation cards, always with the value pinned to the card's inner right
/// edge.
struct ShopValueRow: View {
    let label: String
    let value: String
    var labelFont: Font = Shop.TypeStyle.body
    var valueFont: Font = Shop.TypeStyle.price
    var labelColor: Color = Shop.Palette.secondaryText
    var valueColor: Color = Shop.Palette.primaryText
    let identifier: String

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(labelFont)
                .foregroundColor(labelColor)
                .designNode("\(identifier)-label")
            Spacer(minLength: 0)
            Text(value)
                .font(valueFont)
                .foregroundColor(valueColor)
                .designNode("\(identifier)-value")
        }
        .accessibilityElement(children: .contain)
        .designNode(identifier)
    }
}

/// Screen scaffolding.
///
/// Whether a screen reserves the status bar decides how its design frame is
/// anchored, and the two must agree. A screen that respects the safe area is
/// described by a spec with `origin: "safeArea"`, and its design frame says
/// 24 — the device's inset is added at comparison time, so the same numbers
/// hold on a phone with a Dynamic Island, one with a notch, and one with
/// neither. A screen that opts out is described with `origin: "screen"` and
/// its frame is measured from the physical top.
///
/// Two screens here opt out, and both for a reason: the detail hero runs
/// full-bleed under the status bar, and the confirmation icon starts at 120,
/// already clear of any inset.
///
/// Getting the pair out of step is not cosmetic — every element lands at a
/// constant offset. PrismKit now reports that as a single `screenOffset`
/// finding rather than one per element, but the screen is still wrong.
struct ShopScreen<Content: View>: View {
    var identifier: String
    var respectsTopSafeArea: Bool = true
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            Shop.Palette.screenBackground
                .ignoresSafeArea()
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea(edges: respectsTopSafeArea ? [] : .top)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier(identifier)
    }
}
