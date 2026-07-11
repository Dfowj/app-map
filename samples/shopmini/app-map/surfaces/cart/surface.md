---
id: cart
title: Cart
kind: tab-root
code_anchor:
  file: Sources/ShopMini/Cart/CartView.swift
  symbol: CartView
contains: []
edges:
  - id: checkout-cta
    to: checkout
    via: present
    presentation: sheet
    trigger: "Tap 'Checkout'"
    note: >
      Only enabled when cart total > $0 and a shipping address is on file
      (see CartViewModel.isCheckoutEnabled).
  - id: line-item-tap
    to: product-detail
    via: push
    trigger: "Tap a line item"
entry_points:
  - { type: deepLink, value: "shopmini://cart", to: cart }
states:
  - { name: default, screenshot: screenshot.default.png }
  - { name: empty,   screenshot: screenshot.empty.png }
dependencies:
  external: []
  data:
    - { type: model, name: Cart }
    - { type: fetch, name: "GET /cart", note: "Paginated for >50 items." }
needs_review: false
---

## Description

The shopping cart. Shows line items or an empty state, and gates the checkout
sheet. Reachable externally via the `shopmini://cart` deep link.

## Notes

`empty` vs `default` is driven by `CartViewModel.isEmpty`.
