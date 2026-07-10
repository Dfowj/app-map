---
id: profile
title: Profile
kind: tab-root
code_anchor:
  file: Sources/ShopMini/Profile/ProfileView.swift
  symbol: ProfileView
contains: []
edges: []
entry_points: []
states:
  - { name: default }
dependencies:
  external: []
  data:
    - { type: model, name: Order }
    - { type: fetch, name: "GET /orders" }
needs_review: false
---

## Description

Account tab: shopper identity and a list of past orders.
