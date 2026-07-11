import SwiftUI

/// The tab bar. Structurally *contains* the four tab roots; switching tabs is a
/// switch, not a navigation push.
struct RootTabView: View {
    @EnvironmentObject private var cart: CartViewModel

    enum Tab { case home, search, cart, profile }

    var body: some View {
        TabView(selection: $cart.selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            CartView()
                .tabItem { Label("Cart", systemImage: "cart") }
                .badge(cart.itemCount)
                .tag(Tab.cart)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(Tab.profile)
        }
    }
}
