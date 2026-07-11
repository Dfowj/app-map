import SwiftUI

/// Profile tab: account info and past orders.
struct ProfileView: View {
    @State private var orders: [Order] = []
    private let service = ProductService()

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    Text("Guest shopper")
                }
                Section("Orders") {
                    ForEach(orders) { order in
                        HStack {
                            Text(order.id)
                            Spacer()
                            Text(order.total, format: .currency(code: "USD"))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .task { orders = await service.orders() }
        }
    }
}
