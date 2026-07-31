import SwiftUI
import PrismKit

/// A realistic shop app to challenge PrismKit: navigation, a whole purchase
/// flow — with zero `.measure()` instrumentation. Everything the companion
/// shows comes from the accessibility tree.
///
/// The measurement scope wraps the NavigationStack, so pushed screens stream
/// their elements automatically as you navigate.
///
/// Every screen is built from `Example.pen`, and drifts from it on purpose in
/// a few places. DESIGN-DEMO.md lists each defect and the finding it should
/// produce.
///
/// Launching with `-autopush <slug>` opens a screen directly, which is what
/// makes the guide reproducible: `detail`, `cart`, `checkout` and
/// `confirmation` jump into the flow, and a product slug (e.g. `sneakers`)
/// opens that product's detail.
struct PlaygroundScreen: View {
    @State private var path: [ShopRoute] = Self.autopushPath()

    var body: some View {
        NavigationStack(path: $path) {
            ShopHomeScreen()
                .navigationDestination(for: ShopRoute.self) { route in
                    switch route {
                    case .product(let product): ProductDetailScreen(product: product)
                    case .cart: CartScreen()
                    case .checkout: CheckoutScreen()
                    case .confirmation: ConfirmationScreen()
                    case .uikit: UIKitScreen().ignoresSafeArea(edges: .bottom)
                    }
                }
        }
        // No configuration: the defaults are already quiet, and this used to
        // pass three of them as false to make them so. The floating toolbar is
        // automatic — it shows when testing on device (no companion) and steps
        // aside while the Mac companion is connected.
        .measureScope()
    }

    /// Resolves `-autopush <slug>` into the stack the app opens with. A screen
    /// deep in the flow pushes the ones above it too, so going back from a
    /// deep link behaves like the real thing.
    private static func autopushPath() -> [ShopRoute] {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-autopush"),
              arguments.indices.contains(flagIndex + 1)
        else { return [] }

        let slug = arguments[flagIndex + 1]
        let detail = ShopRoute.product(.named("headphones"))

        switch slug {
        case "home": return []
        case "detail": return [detail]
        case "cart": return [detail, .cart]
        case "checkout": return [detail, .cart, .checkout]
        case "confirmation": return [detail, .cart, .checkout, .confirmation]
        case "uikit": return [.uikit]
        default:
            guard let product = Product.all.first(where: { $0.slug == slug }) else { return [] }
            return [.product(product)]
        }
    }
}

struct PlaygroundScreen_Previews: PreviewProvider {
    static var previews: some View {
        PlaygroundScreen()
    }
}
