---
id: search
title: Search
kind: tab-root
code_anchor:
  file: Sources/ShopMini/Search/SearchView.swift
  symbol: SearchView
contains: []
edges:
  - id: result-tap
    to: product-detail
    via: push
    trigger: "Tap a search result"
entry_points: []
states:
  - { name: default }
dependencies:
  external: []
  data:
    - { type: model, name: Product }
    - { type: fetch, name: "GET /products", note: "Filtered client-side in the stub." }
needs_review: false
---

## Description

Catalog search. A `.searchable` field over the product list; results push into
product detail.
