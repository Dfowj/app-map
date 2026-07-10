import SwiftUI

/// Pushed product screen. "Add to Cart" mutates cart state — it is not a
/// navigation edge.
struct ProductDetailView: View {
    let product: Product
    @EnvironmentObject private var cart: CartViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Color.gray.opacity(0.15).frame(height: 260).cornerRadius(12)
                Text(product.name).font(.title2).bold()
                Text(product.price, format: .currency(code: "USD"))
                Text(product.blurb).foregroundStyle(.secondary)
                Button("Add to Cart") { cart.add(product) }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
