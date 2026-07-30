import SwiftUI

// This app is built from `Example.pen`, and it deliberately drifts from it in
// a handful of places so the design check has something true to find. Do not
// "fix" a spacing value here because it looks off — check DESIGN-DEMO.md first,
// which lists every intentional defect and the finding it should produce.

// MARK: - Model

struct Product: Identifiable, Hashable {
    let slug: String
    let name: String
    let price: String
    let tagline: String
    let symbol: String
    let colors: [Color]

    var id: String { slug }

    static let all: [Product] = [
        Product(slug: "headphones", name: "Studio Headphones", price: "$249", tagline: "Noise cancelling, 40h battery", symbol: "headphones", colors: [.blue, .indigo]),
        Product(slug: "sneakers", name: "Trail Sneakers", price: "$129", tagline: "Lightweight waterproof mesh", symbol: "figure.run", colors: [.orange, .pink]),
        Product(slug: "watch", name: "Field Watch", price: "$399", tagline: "Sapphire glass, 100m", symbol: "applewatch", colors: [.teal, .green]),
        Product(slug: "backpack", name: "Commuter Backpack", price: "$89", tagline: "22L, laptop sleeve", symbol: "backpack", colors: [.purple, .blue]),
        Product(slug: "camera", name: "Compact Camera", price: "$599", tagline: "28mm f/1.8, RAW", symbol: "camera", colors: [.gray, .black]),
        Product(slug: "lamp", name: "Desk Lamp", price: "$49", tagline: "Warm dimmable LED", symbol: "lamp.desk", colors: [.yellow, .orange]),
    ]

    static func named(_ slug: String) -> Product {
        all.first { $0.slug == slug } ?? all[0]
    }

    /// What the cart holds throughout the demo. The design's totals are built
    /// from exactly these three.
    static let cart: [Product] = [named("headphones"), named("sneakers"), named("lamp")]

    /// "$249" → 249, so the totals are computed rather than restated.
    var amount: Int { Int(price.dropFirst()) ?? 0 }
}

/// Where the shop can navigate. The whole flow lives in one stack so every
/// pushed screen streams under the same measurement scope.
enum ShopRoute: Hashable {
    case product(Product)
    case cart
    case checkout
    case confirmation
    /// A screen with no SwiftUI in it, to prove the tree does not care.
    case uikit
}

// MARK: - Home

struct ShopHomeScreen: View {
    private let featured = ["headphones", "sneakers", "watch"].map(Product.named)
    private let popular = ["backpack", "camera", "lamp"].map(Product.named)

    var body: some View {
        ShopScreen(identifier: "screen-home") {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "Shop")
                    .font(Shop.TypeStyle.screenTitle)
                    .foregroundColor(Shop.Palette.primaryText)
                    .designNode("home-title")
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.xxl)

                searchField
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.lg)

                Text(verbatim: "Featured")
                    .font(Shop.TypeStyle.sectionTitle)
                    .foregroundColor(Shop.Palette.primaryText)
                    .designNode("home-featured-title")
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.xxl)

                featuredRail
                    .padding(.top, Shop.Space.md)

                Text(verbatim: "Popular")
                    .font(Shop.TypeStyle.sectionTitle)
                    .foregroundColor(Shop.Palette.primaryText)
                    .designNode("home-popular-title")
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.xxl)

                popularList
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.md)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: Shop.Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Shop.Palette.secondaryText)
                .frame(width: 20, height: 20)
                // Decorative: the placeholder beside it already says what the
                // field is for, and an unhidden SF Symbol announces itself by
                // name, in the simulator's language rather than the app's.
                .accessibilityHidden(true)
                .designNode("home-search-icon")
            Text(verbatim: "Search products")
                .font(Shop.TypeStyle.body)
                .foregroundColor(Shop.Palette.secondaryText)
                .designNode("home-search-placeholder")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Shop.Space.md)
        .frame(height: 36)
        .background(Shop.Palette.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: Shop.Radius.pill, style: .continuous))
        .accessibilityElement(children: .contain)
        .designNode("home-search")
    }

    private var featuredRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Shop.Space.md) {
                ForEach(featured) { product in
                    NavigationLink(value: ShopRoute.product(product)) {
                        FeaturedCard(product: product)
                    }
                    .buttonStyle(.plain)
                    .modifier(ProductAccessibility(product: product))
                }
            }
            .designNode("home-featured-rail")
            .padding(.horizontal, Shop.screenMargin)
        }
        .accessibilityElement(children: .contain)
    }

    private var popularList: some View {
        VStack(spacing: Shop.Space.md) {
            ForEach(popular) { product in
                NavigationLink(value: ShopRoute.product(product)) {
                    PopularRow(product: product)
                }
                .buttonStyle(.plain)
                // On the link rather than inside it: NavigationLink flattens
                // its own label, so grouping applied underneath is overridden.
                .modifier(ProductAccessibility(product: product, includesTagline: true))
            }
        }
        .accessibilityElement(children: .contain)
        .designNode("home-popular-list")
    }
}

private struct FeaturedCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: Shop.Space.sm) {
            ProductThumbnail(
                product: product,
                size: CGSize(width: 124, height: 108),
                glyphSize: 48,
                identifier: "home-featured-\(product.slug)-image"
            )
            VStack(alignment: .leading, spacing: Shop.Space.xs) {
                Text(product.name)
                    .font(Shop.TypeStyle.body)
                    .foregroundColor(Shop.Palette.primaryText)
                    .lineLimit(1)
                    .designNode("home-featured-\(product.slug)-name")
                Text(product.price)
                    .font(Shop.TypeStyle.price)
                    .foregroundColor(Shop.Palette.primaryText)
                    .designNode("home-featured-\(product.slug)-price")
            }
            .frame(width: 124, alignment: .leading)
            .accessibilityElement(children: .contain)
            .designNode("home-featured-\(product.slug)-text")
        }
        .padding(Shop.Space.md)
        .background(Shop.Palette.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: Shop.Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
        .designNode("home-featured-\(product.slug)")
    }
}

private struct PopularRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: Shop.Space.md) {
            ProductThumbnail(
                product: product,
                size: CGSize(width: 56, height: 56),
                glyphSize: 28,
                identifier: "home-popular-\(product.slug)-image"
            )
            VStack(alignment: .leading, spacing: Shop.Space.xs) {
                Text(product.name)
                    .font(Shop.TypeStyle.body)
                    .foregroundColor(Shop.Palette.primaryText)
                    .designNode("home-popular-\(product.slug)-name")
                Text(product.tagline)
                    .font(Shop.TypeStyle.pillCaption)
                    .foregroundColor(Shop.Palette.secondaryText)
                    .designNode("home-popular-\(product.slug)-tagline")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .designNode("home-popular-\(product.slug)-text")
            Text(product.price)
                .font(Shop.TypeStyle.price)
                .foregroundColor(Shop.Palette.primaryText)
                .designNode("home-popular-\(product.slug)-price")
        }
        .padding(Shop.Space.md)
        .background(Shop.Palette.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: Shop.Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
        .designNode("home-popular-\(product.slug)")
    }
}

/// One VoiceOver stop per product, reading the whole card rather than a
/// fragment of it.
///
/// `ignore` plus an explicit label is not a stylistic preference here, it is
/// the only thing that worked. Measured on this screen with the accessibility
/// reader: `contain` left a row reading "$89. button" and `combine` left one
/// reading "$599. button" — name and description lost in both — and moving the
/// modifier onto the NavigationLink changed nothing. Grouping also excludes the
/// product image, which is what fixed cards announcing themselves by SF Symbol
/// name ("Audiolibro" for headphones, in the simulator's language rather than
/// the app's).
///
/// The cost is worth knowing: grouping removes the children's own elements, so
/// a design check can no longer compare their copy. Better VoiceOver, less copy
/// checking.
struct ProductAccessibility: ViewModifier {
    let product: Product
    /// Cards announce name and price; rows also carry the tagline.
    var includesTagline = false

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: label))
            .accessibilityAddTraits(.isButton)
    }

    private var label: String {
        includesTagline
            ? "\(product.name), \(product.tagline), \(product.price)"
            : "\(product.name), \(product.price)"
    }
}

// MARK: - Product detail

struct ProductDetailScreen: View {
    let product: Product

    var body: some View {
        ShopScreen(identifier: "screen-product-detail", respectsTopSafeArea: false) {
            VStack(alignment: .leading, spacing: 0) {
                hero

                Text(product.name)
                    .font(Shop.TypeStyle.screenTitle)
                    .foregroundColor(Shop.Palette.primaryText)
                    .designNode("detail-name")
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.xl)

                Text(product.price)
                    .font(Shop.TypeStyle.emphasizedRow)
                    .foregroundColor(Shop.Palette.brandBlue)
                    .designNode("detail-price")
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.xs)

                Text(product.tagline)
                    .font(Shop.TypeStyle.body)
                    .foregroundColor(Shop.Palette.secondaryText)
                    .designNode("detail-tagline")
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.sm)

                specsCard
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.xxl)

                NavigationLink(value: ShopRoute.cart) {
                    Text(verbatim: "Add to cart")
                        .font(Shop.TypeStyle.emphasizedRow)
                        .foregroundColor(.white)
                        .designNode("detail-add-button-label")
                        .frame(maxWidth: .infinity)
                        .frame(height: Shop.buttonHeight)
                        .background(Shop.Palette.brandBlue)
                        .clipShape(RoundedRectangle(cornerRadius: Shop.Radius.button, style: .continuous))
                }
                .buttonStyle(.plain)
                .designNode("detail-add-button")
                .padding(.horizontal, Shop.screenMargin)
                .padding(.top, Shop.Space.xxl)
            }
        }
    }

    private var hero: some View {
        LinearGradient(colors: product.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .frame(height: 280)
            .overlay(
                Image(systemName: product.symbol)
                    .font(.system(size: 58, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 96, height: 96)
                    .designNode("detail-hero-glyph")
            )
            .accessibilityElement(children: .contain)
            .designNode("detail-hero")
    }

    private var specsCard: some View {
        ShopCard(horizontalPadding: Shop.Space.md, spacing: Shop.Space.md) {
            ShopValueRow(label: "Battery", value: "40 hours", identifier: "detail-spec-battery")
            ShopValueRow(label: "Weight", value: "268 g", identifier: "detail-spec-weight")
            ShopValueRow(label: "Warranty", value: "2 years", identifier: "detail-spec-warranty")
        }
        .accessibilityElement(children: .contain)
        .designNode("detail-specs-card")
    }
}
