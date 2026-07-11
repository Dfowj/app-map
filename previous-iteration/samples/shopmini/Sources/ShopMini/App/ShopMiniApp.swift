import SwiftUI

/// App entry point. Hosts the root tab bar and routes deep links.
@main
struct ShopMiniApp: App {
    @StateObject private var cart = CartViewModel()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(cart)
                .onOpenURL { url in
                    // Entry point: shopmini://cart  ->  Cart tab
                    if url.scheme == "shopmini", url.host == "cart" {
                        cart.selectTab(.cart)
                    }
                }
        }
    }
}
