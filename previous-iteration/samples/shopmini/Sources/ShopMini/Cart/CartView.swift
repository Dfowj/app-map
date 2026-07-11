import SwiftUI

/// Cart tab. Two states: `empty` and `default`. Presents Checkout as a sheet;
/// tapping a line item pushes ProductDetailView.
struct CartView: View {
    @EnvironmentObject private var model: CartViewModel
    @State private var showCheckout = false

    var body: some View {
        NavigationStack {
            Group {
                if model.isEmpty {
                    ContentUnavailableView("Your cart is empty",
                                           systemImage: "cart",
                                           description: Text("Browse the shop to add items."))
                } else {
                    List {
                        ForEach(model.cart.lineItems) { item in
                            NavigationLink(value: item.product) {
                                LineItemRow(item: item)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Cart")
            .navigationDestination(for: Product.self) { product in
                ProductDetailView(product: product)
            }
            .safeAreaInset(edge: .bottom) {
                Button("Checkout") { showCheckout = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.isCheckoutEnabled)
                    .padding()
            }
            .sheet(isPresented: $showCheckout) {
                CheckoutView(total: model.total)
            }
        }
    }
}

private struct LineItemRow: View {
    let item: Cart.LineItem
    var body: some View {
        HStack {
            Text(item.product.name)
            Spacer()
            Text("×\(item.quantity)").foregroundStyle(.secondary)
        }
    }
}
