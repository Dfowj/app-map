import Foundation

struct Cart {
    struct LineItem: Identifiable, Hashable {
        let id = UUID()
        let product: Product
        var quantity: Int
    }

    private(set) var lineItems: [LineItem]

    static let empty = Cart(lineItems: [])

    var total: Decimal {
        lineItems.reduce(0) { $0 + $1.product.price * Decimal($1.quantity) }
    }

    mutating func add(_ product: Product) {
        if let idx = lineItems.firstIndex(where: { $0.product == product }) {
            lineItems[idx].quantity += 1
        } else {
            lineItems.append(LineItem(product: product, quantity: 1))
        }
    }

    mutating func remove(_ item: LineItem) {
        lineItems.removeAll { $0.id == item.id }
    }
}
