# TODOs / nice-to-haves

Future tasks and improvements surfaced during sessions but out of scope at the
time. The plan's "Parked" section holds larger milestone-adjacent items; this is
for smaller, looser threads.

- [x] Regenerate `samples/shopmini/app-map/rendered/` once `appmap render`
  exists (Milestone 3) — the committed HTML is stale previous-iteration output
  and still references the removed abandoned-cart push entry point.
  *(Done 2026-07-13: the stale HTML was on disk but never tracked; `appmap
  render` now regenerates it, and `rendered/` stays gitignored.)*
- [ ] Linux binary for `bin/appmap` — the committed universal binary is
  macOS-only; CI or Linux devs would need a build from `cli/`.
- [ ] Graph page edge labels: triggers are hover-only tooltips today; consider
  optional inline labels once maps get bigger and hover discovery falls short.
