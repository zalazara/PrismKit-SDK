import SwiftUI

// Built from `Example.pen`, with deliberate drift. See DESIGN-DEMO.md before
// changing any spacing value here.

// MARK: - Cart

struct CartScreen: View {
    private let items = Product.cart

    private var subtotal: String {
        let sum = items.reduce(0) { $0 + $1.amount }
        return "$\(sum)"
    }

    var body: some View {
        ShopScreen(identifier: "screen-cart") {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "Cart")
                    .font(Shop.TypeStyle.screenTitle)
                    .foregroundColor(Shop.Palette.primaryText)
                    .designNode("cart-title")
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.xxl)

                itemsCard
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.xxl)

                subtotalRow
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.lg)

                NavigationLink(value: ShopRoute.checkout) {
                    Text(verbatim: "Checkout")
                        .font(Shop.TypeStyle.emphasizedRow)
                        .foregroundColor(.white)
                        .designNode("cart-checkout-button-label")
                        .frame(maxWidth: .infinity)
                        .frame(height: Shop.buttonHeight)
                        .background(Shop.Palette.brandBlue)
                        .clipShape(RoundedRectangle(cornerRadius: Shop.Radius.button, style: .continuous))
                }
                .buttonStyle(.plain)
                .designNode("cart-checkout-button")
                .padding(.horizontal, Shop.screenMargin)
                .padding(.top, Shop.Space.xxl)
            }
        }
    }

    private var itemsCard: some View {
        ShopCard(spacing: Shop.Space.sm) {
            ForEach(items) { product in
                CartRow(product: product)
            }
        }
        .accessibilityElement(children: .contain)
        .designNode("cart-items-card")
    }

    private var subtotalRow: some View {
        HStack(spacing: 0) {
            Text(verbatim: "Subtotal")
                .font(Shop.TypeStyle.body)
                .foregroundColor(Shop.Palette.secondaryText)
                .designNode("cart-subtotal-label")
            Spacer(minLength: 0)
            Text(subtotal)
                .font(Shop.TypeStyle.emphasizedRow)
                .foregroundColor(Shop.Palette.primaryText)
                .designNode("cart-subtotal-value")
        }
        .accessibilityElement(children: .contain)
        .designNode("cart-subtotal-row")
    }
}

private struct CartRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: Shop.Space.md) {
            ProductThumbnail(
                product: product,
                size: CGSize(width: 48, height: 48),
                glyphSize: 24,
                identifier: "cart-item-\(product.slug)-image"
            )
            // Decorative: the name is right beside it, and an unhidden SF
            // Symbol announces itself by name in the simulator's language.
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Shop.Space.sm) {
                Text(product.name)
                    .font(Shop.TypeStyle.body)
                    .foregroundColor(Shop.Palette.primaryText)
                    .designNode("cart-item-\(product.slug)-name")
                stepper
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .designNode("cart-item-\(product.slug)-text")
            Text(product.price)
                .font(Shop.TypeStyle.price)
                .foregroundColor(Shop.Palette.primaryText)
                .designNode("cart-item-\(product.slug)-price")
        }
        .accessibilityElement(children: .contain)
        .designNode("cart-item-\(product.slug)")
    }

    private var stepper: some View {
        HStack(spacing: 0) {
            Text(verbatim: "−")
                .designNode("cart-item-\(product.slug)-stepper-minus")
            Spacer(minLength: 0)
            Text(verbatim: "1")
                .designNode("cart-item-\(product.slug)-stepper-quantity")
            Spacer(minLength: 0)
            Text(verbatim: "+")
                .designNode("cart-item-\(product.slug)-stepper-plus")
        }
        .font(Shop.TypeStyle.pillCaption)
        .foregroundColor(Shop.Palette.primaryText)
        .padding(.horizontal, Shop.Space.md)
        .frame(width: 96, height: 32)
        .background(Shop.Palette.screenBackground)
        .clipShape(RoundedRectangle(cornerRadius: Shop.Radius.pill, style: .continuous))
        // Grouped, but left as its own stop rather than folded into the row:
        // it is a control, and a control merged into a label stops being
        // reachable.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Quantity"))
        .accessibilityValue(Text(verbatim: "1"))
        .designNode("cart-item-\(product.slug)-stepper")
    }
}

// MARK: - Checkout

struct CheckoutScreen: View {
    private let items = Product.cart

    private var total: String {
        let sum = items.reduce(0) { $0 + $1.amount }
        return "$\(sum)"
    }

    /// The design states a fixed date because a mock has to state something.
    /// The app computes the real one, so the two legitimately disagree — the
    /// demo uses this to show what a false positive looks like and how to
    /// silence it. See DESIGN-DEMO.md.
    private var deliveryEstimate: String {
        let date = Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date()
        let formatter = DateFormatter()
        // Pinned to en_US_POSIX so the string does not change with the
        // simulator's language: the design states an English date, and a
        // locale-shifted one would look like a different defect than it is.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, MMM d"
        return "Arrives " + formatter.string(from: date)
    }

    var body: some View {
        ShopScreen(identifier: "screen-checkout") {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "Review order")
                    .font(Shop.TypeStyle.screenTitle)
                    .foregroundColor(Shop.Palette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .designNode("checkout-title")
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.xxl)

                itemsCard
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.xxl)

                deliveryRow
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.md)

                Text(verbatim: "Payment Summary")
                    .font(Shop.TypeStyle.sectionTitle)
                    .foregroundColor(Shop.Palette.primaryText)
                    .designNode("checkout-summary-title")
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.xxxl)

                summaryCard
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.lg)

                NavigationLink(value: ShopRoute.confirmation) {
                    Text(verbatim: "Place order")
                        .font(Shop.TypeStyle.emphasizedRow)
                        .foregroundColor(.white)
                        .designNode("checkout-place-order-button-label")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Shop.Palette.brandBlue)
                        .clipShape(RoundedRectangle(cornerRadius: Shop.Radius.button, style: .continuous))
                }
                .buttonStyle(.plain)
                .designNode("checkout-place-order-button")
                .padding(.horizontal, Shop.screenMargin)
                .padding(.top, Shop.Space.xxxl)

                Text(verbatim: "Taxes calculated at checkout. 30-day returns.")
                    .font(Shop.TypeStyle.legal)
                    .foregroundColor(Shop.Palette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .designNode("checkout-legal-caption")
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.md)
            }
        }
    }

    private var itemsCard: some View {
        ShopCard(spacing: Shop.Space.lg) {
            ForEach(items) { product in
                CheckoutRow(product: product)
            }
        }
        .accessibilityElement(children: .contain)
        .designNode("checkout-items-card")
    }

    private var deliveryRow: some View {
        HStack(spacing: Shop.Space.sm) {
            Text(verbatim: "Free shipping")
                .font(Shop.TypeStyle.pillCaption)
                .foregroundColor(Shop.Palette.pillGreenText)
                .designNode("checkout-delivery-badge-label")
                .padding(.horizontal, Shop.Space.md)
                .padding(.vertical, Shop.Space.xs)
                .background(Shop.Palette.pillGreenBackground)
                .clipShape(RoundedRectangle(cornerRadius: Shop.Radius.pill, style: .continuous))
                .designNode("checkout-delivery-badge")

            Text(deliveryEstimate)
                .font(Shop.TypeStyle.pillCaption)
                .foregroundColor(Shop.Palette.secondaryText)
                .designNode("checkout-delivery-estimate")

            Spacer(minLength: 0)
        }
    }

    private var summaryCard: some View {
        ShopCard(spacing: Shop.Space.md) {
            ShopValueRow(label: "Subtotal", value: total, identifier: "checkout-summary-subtotal")
            ShopValueRow(label: "Shipping", value: "Free", identifier: "checkout-summary-shipping")
            Rectangle()
                .fill(Shop.Palette.divider)
                .frame(height: 1)
                // A rule between rows says nothing out loud; without this it
                // announces itself as an element with no content.
                .accessibilityHidden(true)
                .designNode("checkout-summary-divider")
            ShopValueRow(
                label: "Total",
                value: total,
                labelFont: Shop.TypeStyle.emphasizedRow,
                valueFont: Shop.TypeStyle.emphasizedRow,
                labelColor: Shop.Palette.primaryText,
                identifier: "checkout-summary-total"
            )
        }
        .accessibilityElement(children: .contain)
        .designNode("checkout-summary-card")
    }
}

private struct CheckoutRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: Shop.Space.md) {
            ProductThumbnail(
                product: product,
                size: CGSize(width: 48, height: 48),
                glyphSize: 24,
                identifier: "checkout-item-\(product.slug)-image"
            )
            Text(product.name)
                .font(Shop.TypeStyle.body)
                .foregroundColor(Shop.Palette.primaryText)
                .designNode("checkout-item-\(product.slug)-name")
            Spacer(minLength: 0)
            Text(product.price)
                .font(Shop.TypeStyle.price)
                .foregroundColor(Shop.Palette.primaryText)
                .designNode("checkout-item-\(product.slug)-price")
        }
        .modifier(ProductAccessibility(product: product))
        .designNode("checkout-item-\(product.slug)")
    }
}

// MARK: - Confirmation

struct ConfirmationScreen: View {
    private var total: String {
        let sum = Product.cart.reduce(0) { $0 + $1.amount }
        return "$\(sum)"
    }

    var body: some View {
        ShopScreen(identifier: "screen-confirmation", respectsTopSafeArea: false) {
            VStack(alignment: .leading, spacing: 0) {
                successIcon
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 120)

                Text(verbatim: "Order placed")
                    .font(Shop.TypeStyle.screenTitle)
                    .foregroundColor(Shop.Palette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .designNode("confirmation-title")
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.xxl)

                Text(verbatim: "We sent a receipt to your email.")
                    .font(Shop.TypeStyle.body)
                    .foregroundColor(Shop.Palette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .designNode("confirmation-subtitle")
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.sm)

                detailsCard
                    .padding(.horizontal, Shop.screenMargin)
                    .padding(.top, Shop.Space.xxxl)

                NavigationLink(value: ShopRoute.cart) {
                    Text(verbatim: "Continue shopping")
                        .font(Shop.TypeStyle.emphasizedRow)
                        .foregroundColor(.white)
                        .designNode("confirmation-continue-button-label")
                        .frame(maxWidth: .infinity)
                        .frame(height: Shop.buttonHeight)
                        .background(Shop.Palette.brandBlue)
                        .clipShape(RoundedRectangle(cornerRadius: Shop.Radius.button, style: .continuous))
                }
                .buttonStyle(.plain)
                .designNode("confirmation-continue-button")
                .padding(.horizontal, Shop.screenMargin)
                .padding(.top, Shop.Space.xxl)
            }
        }
    }

    private var successIcon: some View {
        Circle()
            .fill(Shop.Palette.pillGreenBackground)
            .frame(width: 72, height: 72)
            .overlay(
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(Shop.Palette.pillGreenText)
                    .frame(width: 36, height: 36)
                    .designNode("confirmation-icon-glyph")
            )
            .accessibilityElement(children: .contain)
            .designNode("confirmation-icon")
    }

    private var detailsCard: some View {
        ShopCard(spacing: Shop.Space.md) {
            ShopValueRow(label: "Order", value: "#10482", identifier: "confirmation-order-number")
            ShopValueRow(label: "Total", value: total, identifier: "confirmation-total")
            ShopValueRow(label: "Delivery", value: "Thu, Aug 6", identifier: "confirmation-delivery")
        }
        .accessibilityElement(children: .contain)
        .designNode("confirmation-details-card")
    }
}
