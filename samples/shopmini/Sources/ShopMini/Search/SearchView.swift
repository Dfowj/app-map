import SwiftUI

/// Search tab: a search field over the catalog. Tapping a result pushes
/// ProductDetailView.
struct SearchView: View {
    @State private var query = ""
    @State private var results: [Product] = []
    private let service = ProductService()

    var body: some View {
        NavigationStack {
            List(results) { product in
                NavigationLink(value: product) {
                    Text(product.name)
                }
            }
            .navigationTitle("Search")
            .navigationDestination(for: Product.self) { product in
                ProductDetailView(product: product)
            }
            .searchable(text: $query)
            .task(id: query) {
                results = await service.search(query)
            }
        }
    }
}
