---
id: product-detail
title: Product Detail
kind: screen
code_anchor:
  file: Sources/ShopMini/Product/ProductDetailView.swift
  symbol: ProductDetailView
contains: []
edges: []
entry_points: []
states:
  - { name: default }
dependencies:
  external: []
  data:
    - { type: model, name: Product }
needs_review: false
---

## Description

Pushed product screen with imagery, price, blurb, and an Add-to-Cart action.
Reached from Home, Search, and the Cart's line items.

## Notes

"Add to Cart" mutates `CartViewModel` — it is deliberately **not** a navigation
edge.
