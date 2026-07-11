---
id: checkout
title: Checkout
kind: sheet
code_anchor:
  file: Sources/ShopMini/Checkout/CheckoutView.swift
  symbol: CheckoutView
contains: []
edges: []
entry_points: []
states:
  - { name: default }
dependencies:
  external: [Stripe]
  data:
    - { type: model, name: Cart }
needs_review: false
---

## Description

Presented sheet that collects shipping and payment and charges via Stripe. On
success it dismisses back to the cart.

## Notes

Stripe is the only notable external dependency and is scoped entirely to this
surface.
