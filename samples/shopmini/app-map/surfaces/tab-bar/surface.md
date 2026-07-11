---
id: tab-bar
title: Tab Bar
kind: tab-bar
code_anchor:
  file: Sources/ShopMini/App/RootTabView.swift
  symbol: RootTabView
contains: [home, search, cart, profile]
edges: []
entry_points: []
states:
  - { name: default }
dependencies:
  external: []
  data: []
needs_review: false
---

## Description

The root navigation container. Hosts the four primary tabs and owns tab
selection (including deep-link-driven switches). Contains its tabs structurally;
switching tabs is a switch, not a push.

## Notes

`selectedTab` lives on `CartViewModel` so external entry points (deep links) can
drive tab selection.
