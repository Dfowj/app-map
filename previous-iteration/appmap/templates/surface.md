---
# ── TIER 3 (manual) ─────────────────────────────────────────────────
id: __ID__                     # immutable slug, set once, never changes
# ── TIER 2 (agent-asserted, code-grounded) ──────────────────────────
title: __ID__
kind: screen                   # screen | tab-root | tab-bar | sheet | modal | popover | container
code_anchor:
  file: Sources/Path/To/View.swift
  symbol: ViewName
contains: []                   # structural nesting (tab-bar -> its tab roots). NOT edges.
edges: []                      # OUTGOING navigation only; incoming derived at render.
  # - id: some-cta             # stable key; keep stable once a note is attached
  #   to: other-surface
  #   via: push                # push | present | tab-switch | deep-link
  #   presentation: sheet      # sheet | modal | popover | fullScreen (for present)
  #   trigger: "Tap 'Foo'"
  #   note: >                  # TIER-3, preserved on merge
  #     Human color on how/when this fires.
entry_points: []               # ways in from OUTSIDE the app graph
  # - { type: deepLink, value: "app://path", to: __ID__ }
states:
  - { name: default }
dependencies:
  external: []                 # notable external only, not internal packages
  data: []
    # - { type: model, name: Foo }
    # - { type: fetch, name: "GET /foo" }
# ── TIER 1 (mechanical, script-owned) ───────────────────────────────
needs_review: false
---

## Description

## Goal

## KPIs

## Notes
