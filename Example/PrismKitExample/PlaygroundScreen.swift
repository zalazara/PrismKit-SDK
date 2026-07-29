import SwiftUI
import PrismKit

/// A realistic shop app to challenge PrismKit: navigation, vertical and
/// horizontal scrolling — with zero `.measure()` instrumentation. Everything
/// the companion shows comes from the accessibility tree.
///
/// The measurement scope wraps the NavigationStack, so pushed screens stream
/// their elements automatically as you navigate.
///
/// Launching with `-autopush <slug>` (e.g. `-autopush sneakers`) opens that
/// product's detail directly, which lets scripts verify navigation behavior.
struct PlaygroundScreen: View {
    @State private var path: [Product] = Self.autopushPath()

    var body: some View {
        NavigationStack(path: $path) {
            ShopHomeScreen()
                .navigationDestination(for: Product.self) { product in
                    ProductDetailScreen(product: product)
                }
        }
        // Quiet overlay layers by default. The floating toolbar is automatic:
        // it shows when testing on device (no companion) and steps aside
        // while the Mac companion is connected.
        .measureScope(
            configuration: MeasureConfiguration(
                showsBounds: false,
                showsSizeLabels: false,
                showsInternalPadding: false
            )
        )
    }

    private static func autopushPath() -> [Product] {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-autopush"),
              arguments.indices.contains(flagIndex + 1),
              let product = Product.all.first(where: { $0.slug == arguments[flagIndex + 1] })
        else { return [] }
        return [product]
    }
}

struct PlaygroundScreen_Previews: PreviewProvider {
    static var previews: some View {
        PlaygroundScreen()
    }
}
