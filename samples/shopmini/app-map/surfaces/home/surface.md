---
id: home
title: Home
kind: tab-root
code_anchor:
  file: Sources/ShopMini/Home/HomeView.swift
  symbol: HomeView
contains: []
edges:
  - id: product-tap
    to: product-detail
    via: push
    trigger: "Tap a product card"
entry_points: []
states:
  - { name: default }
dependencies:
  external: []
  data:
    - { type: model, name: Product }
    - { type: fetch, name: "GET /products" }
needs_review: false
---

## Description

The shopping landing surface: an adaptive grid of products. The primary path
into the catalog.

## Goal

Get shoppers into product detail quickly.
