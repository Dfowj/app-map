// Wholesale manifest.yaml build — the derived "front door" index (tier-1).
//
// All fields are derived from the surface records; the manifest is safe to
// regenerate at any time (on a merge conflict, take either side and re-render).
// It deliberately carries no volatile fields (no wall-clock timestamp, no git
// sha of its own) and is emitted by a deterministic hand-rolled YAML writer, so
// a re-render on unchanged records produces a byte-identical file.

import Foundation

public func buildManifestYAML(
    surfaces: [SurfaceRecord], links: LinkGraph, cfg: Config
) -> String {
    var out: [String] = []
    out.append("launch_surface: \(yamlScalar(cfg.launchSurface))")

    if surfaces.isEmpty {
        out.append("surfaces: {}")
    } else {
        out.append("surfaces:")
        for s in surfaces.sorted(by: { $0.id < $1.id }) {
            out.append("  \(yamlScalar(s.id)):")
            out.append("    title: \(yamlScalar(s.title))")
            out.append("    kind: \(yamlScalar(s.kind))")
            out.append("    path: \(yamlScalar("surfaces/\(s.id)/surface.md"))")
            out.append("    last_verified: \(yamlScalar(s.lastVerified["sha"] as? String))")
            out.append("    needs_review: \(s.needsReview)")
        }
    }

    let reviewQueue = surfaces.filter(\.needsReview).map(\.id).sorted()
    if reviewQueue.isEmpty {
        out.append("review_queue: []")
    } else {
        out.append("review_queue:")
        for id in reviewQueue { out.append("- \(yamlScalar(id))") }
    }

    out.append("link_health:")
    if links.dangling.isEmpty {
        out.append("  dangling_links: []")
    } else {
        out.append("  dangling_links:")
        for d in links.dangling {
            out.append("  - from: \(yamlScalar(d.fromID))")
            out.append("    to: \(yamlScalar(d.to))")
            out.append("    kind: \(yamlScalar(d.kind))")
            out.append("    ref: \(yamlScalar(d.ref))")
        }
    }

    return out.joined(separator: "\n") + "\n"
}

/// Emit one YAML scalar: plain when unambiguous, single-quoted otherwise,
/// `null` for nil. Deterministic by construction.
func yamlScalar(_ value: String?) -> String {
    guard let value else { return "null" }
    if value.isEmpty { return "''" }
    let plainSafe = value.range(
        of: "^[A-Za-z0-9][A-Za-z0-9 ._/()-]*$", options: .regularExpression
    ) != nil
    let ambiguous = [
        "null", "~", "true", "false", "yes", "no", "on", "off",
    ].contains(value.lowercased())
        || value.range(of: "^[0-9.+-]", options: .regularExpression) != nil
        || value.hasSuffix(" ")
    if plainSafe && !ambiguous { return value }
    return "'" + value.replacingOccurrences(of: "'", with: "''") + "'"
}
