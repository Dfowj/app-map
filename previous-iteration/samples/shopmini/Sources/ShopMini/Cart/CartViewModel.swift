import SwiftUI

/// Cart state shared across the app. Drives the tab badge, the empty state, and
/// whether checkout is allowed.
@MainActor
final class CartViewModel: ObservableObject {
    @Published var selectedTab: RootTabView.Tab = .home
    @Published private(set) var cart: Cart = .empty
    @Published var hasShippingAddress: Bool = false

    var itemCount: Int { cart.lineItems.reduce(0) { $0 + $1.quantity } }
    var isEmpty: Bool { cart.lineItems.isEmpty }
    var total: Decimal { cart.total }

    /// Checkout is only enabled when the cart has value and an address is on file.
    var isCheckoutEnabled: Bool { total > 0 && hasShippingAddress }

    func selectTab(_ tab: RootTabView.Tab) { selectedTab = tab }

    func add(_ product: Product) {
        cart.add(product)
        objectWillChange.send()
    }

    func remove(_ item: Cart.LineItem) {
        cart.remove(item)
        objectWillChange.send()
    }
}
