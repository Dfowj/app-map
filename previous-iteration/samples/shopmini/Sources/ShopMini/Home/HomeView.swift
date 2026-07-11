import SwiftUI

/// Home tab: a grid of products. Tapping one pushes ProductDetailView.
struct HomeView: View {
    @State private var products: [Product] = []
    private let service = ProductService()

    private let columns = [GridItem(.adaptive(minimum: 150))]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(products) { product in
                        NavigationLink(value: product) {
                            ProductCard(product: product)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Shop")
            .navigationDestination(for: Product.self) { product in
                ProductDetailView(product: product)
            }
            .task { products = await service.products() }
        }
    }
}

private struct ProductCard: View {
    let product: Product
    var body: some View {
        VStack(alignment: .leading) {
            Color.gray.opacity(0.15).frame(height: 120).cornerRadius(8)
            Text(product.name).font(.subheadline)
            Text(product.price, format: .currency(code: "USD")).font(.caption)
        }
    }
}
