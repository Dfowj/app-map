// Surface records: parse frontmatter, load a whole map.
//
// A surface record (`surfaces/<id>/surface.md`) is YAML frontmatter between
// `---` fences followed by a markdown body. The frontmatter carries tier-1
// (script) and tier-2 (agent) fields; the **body is tier-3 (human) prose and is
// preserved verbatim** — no write path may rewrite it as a side effect.

import Foundation
import Yams

public let fence = "---"

public struct SurfaceRecord {
    public let path: URL
    /// Raw frontmatter dict (empty when the file has no frontmatter).
    public var data: [String: Any]
    /// Verbatim markdown after the closing fence (leading newlines stripped,
    /// matching the historical parse; everything else byte-for-byte).
    public var body: String
    /// The exact YAML text between the fences, untouched. Write paths patch
    /// this text line-surgically instead of re-emitting YAML, so hand-authored
    /// formatting survives.
    public var rawFrontmatter: String
    public var hasFrontmatter: Bool

    // ── tier-2/manual accessors (read-only convenience) ──────────────────

    public var id: String {
        data["id"] as? String ?? path.deletingLastPathComponent().lastPathComponent
    }

    public var title: String { data["title"] as? String ?? id }

    public var kind: String { data["kind"] as? String ?? "screen" }

    public var contains: [String] {
        (data["contains"] as? [Any])?.compactMap { $0 as? String } ?? []
    }

    public var edges: [[String: Any]] {
        (data["edges"] as? [Any])?.compactMap { asStringDict($0) } ?? []
    }

    public var entryPoints: [[String: Any]] {
        (data["entry_points"] as? [Any])?.compactMap { asStringDict($0) } ?? []
    }

    public var states: [[String: Any]] {
        (data["states"] as? [Any])?.compactMap { asStringDict($0) } ?? []
    }

    public var codeAnchor: [String: Any] { asStringDict(data["code_anchor"]) ?? [:] }

    /// Additional files whose changes should flag this record for review.
    public var watches: [String] {
        (data["watches"] as? [Any])?.compactMap { $0 as? String } ?? []
    }

    public var dependencies: [String: Any] { asStringDict(data["dependencies"]) ?? [:] }

    public var needsReview: Bool { data["needs_review"] as? Bool ?? false }

    public var lastVerified: [String: Any] { asStringDict(data["last_verified"]) ?? [:] }
}

/// Yams may hand back `[AnyHashable: Any]`; normalize to string keys.
func asStringDict(_ value: Any?) -> [String: Any]? {
    if let d = value as? [String: Any] { return d }
    guard let d = value as? [AnyHashable: Any] else { return nil }
    var out: [String: Any] = [:]
    for (k, v) in d { out["\(k.base)"] = v }
    return out
}

public enum RecordError: Error, CustomStringConvertible {
    case unreadable(URL, underlying: Error)

    public var description: String {
        switch self {
        case .unreadable(let url, let err): return "could not read \(url.path): \(err)"
        }
    }
}

/// Parse a surface.md file. Tolerant: a file with no frontmatter yields an
/// empty `data` and the whole text as `body`; unparseable YAML likewise.
public func parseSurface(at path: URL) throws -> SurfaceRecord {
    let text: String
    do {
        text = try String(contentsOf: path, encoding: .utf8)
    } catch {
        throw RecordError.unreadable(path, underlying: error)
    }
    return parseSurface(text: text, path: path)
}

public func parseSurface(text: String, path: URL) -> SurfaceRecord {
    let leadingTrimmed = String(text.drop(while: { $0.isWhitespace }))
    guard leadingTrimmed.hasPrefix(fence),
          let (rawYAML, rawBody) = splitOnFences(leadingTrimmed)
    else {
        return SurfaceRecord(
            path: path, data: [:], body: text, rawFrontmatter: "", hasFrontmatter: false
        )
    }
    var data: [String: Any] = [:]
    if let loaded = try? Yams.load(yaml: rawYAML), let dict = asStringDict(loaded) {
        data = dict
    }
    let body = String(rawBody.drop(while: { $0 == "\n" }))
    return SurfaceRecord(
        path: path, data: data, body: body, rawFrontmatter: rawYAML, hasFrontmatter: true
    )
}

/// Split `---<yaml>---<body>` on the first two fence occurrences (substring
/// semantics, like Python's `str.split("---", 2)` — a `---` inside the body is
/// left alone because we stop after the second occurrence).
func splitOnFences(_ text: String) -> (yaml: String, body: String)? {
    guard let first = text.range(of: fence) else { return nil }
    let afterFirst = text[first.upperBound...]
    guard let second = afterFirst.range(of: fence) else { return nil }
    let yaml = String(afterFirst[..<second.lowerBound])
    let body = String(afterFirst[second.upperBound...])
    return (yaml, body)
}

/// Load every `surfaces/*/surface.md`, sorted by id for stable output.
public func loadSurfaces(in surfacesDir: URL) -> [SurfaceRecord] {
    let fm = FileManager.default
    var isDir: ObjCBool = false
    guard fm.fileExists(atPath: surfacesDir.path, isDirectory: &isDir), isDir.boolValue else {
        return []
    }
    let entries = (try? fm.contentsOfDirectory(
        at: surfacesDir, includingPropertiesForKeys: [.isDirectoryKey]
    )) ?? []
    var out: [SurfaceRecord] = []
    for dir in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
        let md = dir.appendingPathComponent("surface.md")
        guard fm.fileExists(atPath: md.path) else { continue }
        if let record = try? parseSurface(at: md) { out.append(record) }
    }
    out.sort { $0.id < $1.id }
    return out
}
