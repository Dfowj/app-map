# Change history

Newest first. One paragraph per entry: what changed and why.

## 2026-07-11 — Milestone 1: agent encodes a screen

Built the `dropin/app-map/` drop-in template (`INSTALL.md` + skill + schema) and
validated the app-map skill against `samples/shopmini/`. Both exit criteria
passed: a fresh encode from source reproduced all 7 gold surfaces' tier-2
structure (kinds, anchors, edges, containment, deps), and a reconcile against a
simulated code change touched only the contradicted tier-2 field while every
tier-3 note and body section survived. Tightened the gold `cart` record and the
sample spec to drop an aspirational (non-code-grounded) push-notification entry
point, reinforcing the "entry points must be code-grounded" rule. Refined the
skill's tier-3 boundary: the agent may *add* a code-grounded `note` to a field
lacking one on new *and* existing records, but must never overwrite or delete an
existing note.
