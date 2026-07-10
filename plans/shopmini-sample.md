# shopmini — sample SwiftUI app spec

A small but **coherent, real** SwiftUI shopping app used as the test target for the App Map tool. Its purpose is to be a codebase an agent can *read* to assert tier-2 map fields authentically, and to compare an agent-regenerated map against the hand-authored "gold" records committed under `samples/shopmini/app-map/`.

**Bar:** readable and internally consistent SwiftUI. Compiling/running in a simulator is a nice-to-have, **not required** for map-tool testing — the agent reads code, it doesn't run the app. Keep it minimal; prefer clarity over feature depth.

> Status: a **seed skeleton** already exists (enough view files that every surface's `code_anchor.file`/`symbol` resolves and the engine loop runs green). This spec is the target to flesh it out to in a dedicated session, followed by an agent/skill run.

## Surfaces & navigation

| id | kind | code_anchor symbol → file | edges / containment |
|---|---|---|---|
| `tab-bar` | `tab-bar` | `RootTabView` → App/RootTabView.swift | **contains** `[home, search, cart, profile]`; is `launch_surface` |
| `home` | `tab-root` | `HomeView` → Home/HomeView.swift | push → `product-detail` (tap a product) |
| `search` | `tab-root` | `SearchView` → Search/SearchView.swift | push → `product-detail` (tap a result) |
| `cart` | `tab-root` | `CartView` → Cart/CartView.swift | present sheet → `checkout` (tap "Checkout"); push → `product-detail` (tap a line item) |
| `profile` | `tab-root` | `ProfileView` → Profile/ProfileView.swift | orders list; outgoing edges optional |
| `product-detail` | `screen` | `ProductDetailView` → Product/ProductDetailView.swift | "Add to Cart" mutates cart (**not** an edge) |
| `checkout` | `sheet` | `CheckoutView` → Checkout/CheckoutView.swift | external dep Stripe; on success dismisses. OrderConfirmation modal optional/deferred |

Navigation vocabulary (keep these distinct in code and map):
- **Edge** = a nav transition (push / present / tab-switch / deep-link). Directional, outgoing-only in records.
- **Containment** = `tab-bar` structurally hosting its tabs. Tapping a tab is a *switch*, not a push.
- **Entry point** = a way in from outside the app graph.

## States

- `cart`: `default` and `empty`. (All other surfaces single-state for now.)

## Entry points

- Deep link: `shopmini://cart` → `cart`.
- Push notification: "abandoned-cart reminder" → `cart`.

Implement deep-link routing in `App/ShopMiniApp.swift` (`.onOpenURL`) so the entry point is code-grounded.

## Data dependencies

- Models: `Product`, `Cart`, `Order` (Models/).
- `ProductService` (Services/) with `GET /products` and `GET /cart` (cart paginated for >50 items).
- External: `Stripe` — referenced **only** from `CheckoutView` (so "notable external dep" is genuinely scoped to checkout).

## File layout (maps 1:1 to `code_anchor.file`)

```
samples/shopmini/
  Package.swift                        # SwiftPM, SwiftUI library/app target
  Sources/ShopMini/
    App/ShopMiniApp.swift              # @main, WindowGroup → RootTabView, .onOpenURL deep-link routing
    App/RootTabView.swift              # TabView(Home, Search, Cart, Profile)
    Home/HomeView.swift                # product grid → ProductDetailView
    Search/SearchView.swift            # search field + results → ProductDetailView
    Cart/CartView.swift                # line items; empty state; Checkout button → .sheet(CheckoutView)
    Cart/CartViewModel.swift           # cart state; total; isCheckoutEnabled
    Checkout/CheckoutView.swift        # shipping + payment (Stripe)
    Product/ProductDetailView.swift    # product info; Add to Cart
    Profile/ProfileView.swift          # user + orders
    Models/Product.swift  Models/Cart.swift  Models/Order.swift
    Services/ProductService.swift
```

## When this app is built (separate session)

1. Flesh the seed skeleton into the full app above.
2. Run the (future) **agent skill** against it to regenerate/reconcile the `app-map/` records from code.
3. Diff the agent output against the committed hand-authored gold records to evaluate map quality.

## Screenshots

Records reference placeholder screenshot paths. The validator reports path resolution as a **warning** until a real snapshot-test suite exists (handoff §7E). No manual capture in this phase.
