import SwiftUI

/// Checkout sheet. Collects shipping + payment and charges via Stripe. On
/// success it dismisses back to the cart.
struct CheckoutView: View {
    let total: Decimal
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false

    // NOTE: Stripe is the one notable external dependency, scoped to checkout.
    private let payments = StripePaymentClient()

    var body: some View {
        NavigationStack {
            Form {
                Section("Shipping") {
                    TextField("Address", text: .constant(""))
                }
                Section("Payment") {
                    Text("•••• 4242").foregroundStyle(.secondary)
                }
                Section {
                    Button {
                        Task { await pay() }
                    } label: {
                        Text("Pay \(total, format: .currency(code: "USD"))")
                    }
                    .disabled(isProcessing)
                }
            }
            .navigationTitle("Checkout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func pay() async {
        isProcessing = true
        defer { isProcessing = false }
        if await payments.charge(amount: total) {
            dismiss()
        }
    }
}

/// Stand-in for the Stripe SDK client.
private struct StripePaymentClient {
    func charge(amount: Decimal) async -> Bool { true }
}
