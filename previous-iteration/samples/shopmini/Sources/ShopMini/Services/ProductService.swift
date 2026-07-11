import Foundation

/// Backing data source. `GET /products` and `GET /cart` (the latter paginated
/// for carts over 50 items). Stubbed with in-memory data here.
struct ProductService {
    private let sample: [Product] = [
        Product(id: "p1", name: "Trail Runner", price: 128, blurb: "Lightweight everyday shoe."),
        Product(id: "p2", name: "Wool Beanie", price: 32, blurb: "Merino, one size."),
        Product(id: "p3", name: "Canvas Tote", price: 48, blurb: "Roomy and washable."),
    ]

    /// GET /products
    func products() async -> [Product] { sample }

    func search(_ query: String) async -> [Product] {
        guard !query.isEmpty else { return [] }
        return sample.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    /// GET /cart — paginated for carts with more than 50 line items.
    func cart(page: Int = 0) async -> Cart { .empty }

    func orders() async -> [Order] {
        [Order(id: "1024", total: 160, placedAt: .now)]
    }
}
