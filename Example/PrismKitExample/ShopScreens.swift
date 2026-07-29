import SwiftUI

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
}

// MARK: - Home

/// A brand badge backed by UIKit: UIImageView keeps the image's identity at
/// runtime, so PrismKit can reveal the SF Symbol / asset name — SwiftUI's
/// own Image draws layers that keep no name.
private struct BrandBadge: UIViewRepresentable {
    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView(image: UIImage(systemName: "shippingbox.fill"))
        view.contentMode = .scaleAspectFit
        view.tintColor = .systemBlue
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {}
}

struct ShopHomeScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                searchBar
                featuredSection
                popularSection
                footer
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .navigationTitle("Shop")
    }

    private var footer: some View {
        HStack(spacing: 8) {
            BrandBadge()
                .frame(width: 22, height: 22)
            Text("PrismKit Shop")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
            Text("Search products")
            Spacer(minLength: 0)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Featured")
                .font(.title3.bold())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Product.all.prefix(4)) { product in
                        NavigationLink(value: product) {
                            ProductCard(product: product)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Popular")
                    .font(.title3.bold())
                Spacer()
                Text("See all")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            VStack(spacing: 8) {
                ForEach(Product.all) { product in
                    NavigationLink(value: product) {
                        ProductRow(product: product)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Components

struct ProductCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: product.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 148, height: 108)
                .overlay(
                    Image(systemName: product.symbol)
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.9))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(product.price)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct ProductRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: product.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: product.symbol)
                        .foregroundColor(.white.opacity(0.9))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.body.weight(.medium))
                Text(product.tagline)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(product.price)
                .font(.subheadline.weight(.semibold))
            // .forward flips with the layout direction (RTL locales).
            Image(systemName: "chevron.forward")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Detail

struct ProductDetailScreen: View {
    let product: Product

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: product.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 260)
                    .overlay(
                        Image(systemName: product.symbol)
                            .font(.system(size: 96))
                            .foregroundColor(.white.opacity(0.9))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.title2.bold())
                    Text(product.price)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                Text("\(product.tagline). Designed for everyday use with premium materials and a two-year warranty. Free shipping and 30-day returns included.")
                    .font(.body)
                    .foregroundColor(.secondary)

                VStack(spacing: 0) {
                    specRow("Availability", "In stock")
                    Divider()
                    specRow("Shipping", "2–4 days")
                    Divider()
                    specRow("Warranty", "2 years")
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )

                buyButton
            }
            .padding(16)
        }
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // LocalizedStringKey so the labels resolve through Localizable.xcstrings.
    private func specRow(_ title: LocalizedStringKey, _ value: LocalizedStringKey) -> some View {
        HStack {
            Text(title).foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
        .padding(12)
    }

    private var buyButton: some View {
        Button {
            // Demo only.
        } label: {
            Text("Add to cart — \(product.price)")
                .font(.body.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.blue))
        }
        .buttonStyle(.plain)
    }
}
