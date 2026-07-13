// Validation — the linter's teeth, but warn-only. Never blocks; the CLI exits
// 0 regardless of findings. Severity ranks attention only.
//
// Checks:
//   * frontmatter shape vs surface.schema.json (hand-rolled subset:
//     required/type/enum/pattern — no JSON-schema dependency),
//   * code_anchor resolution (file exists; symbol appears, word-bounded),
//   * screenshot path resolution (state screenshots resolve to a file),
//   * dangling links (edge/contains/entry_point targets with no record).

import Foundation

public enum FindingLevel: String {
    case warn
    case error  // still non-blocking; severity is for the human's attention only
}

public struct Finding {
    public let level: FindingLevel
    public let surface: String
    public let message: String

    public init(_ level: FindingLevel, _ surface: String, _ message: String) {
        self.level = level
        self.surface = surface
        self.message = message
    }
}

// ── tiny JSON-schema-subset validator (required/type/enum/pattern) ──────────

func typeMatches(_ value: Any, _ type: String) -> Bool {
    switch type {
    case "string": return value is String
    case "boolean": return value is Bool
    case "array": return value is [Any]
    case "object": return asStringDict(value) != nil
    case "number": return (value is Int || value is Double) && !(value is Bool)
    default: return true
    }
}

func isNull(_ value: Any) -> Bool { value is NSNull }

func checkNode(_ value: Any, schema: [String: Any], loc: String, out: inout [String]) {
    let type = schema["type"] as? String
    if let type, !isNull(value), !typeMatches(value, type) {
        out.append("\(loc): expected \(type), got \(yamlTypeName(value))")
        return
    }

    if type == "object", let dict = asStringDict(value) {
        for req in (schema["required"] as? [Any])?.compactMap({ $0 as? String }) ?? [] {
            if dict[req] == nil {
                out.append("\(loc): missing required '\(req)'")
            }
        }
        let props = asStringDict(schema["properties"]) ?? [:]
        for (key, sub) in props.sorted(by: { $0.key < $1.key }) {
            guard let subSchema = asStringDict(sub),
                  let subValue = dict[key], !isNull(subValue) else { continue }
            checkNode(subValue, schema: subSchema, loc: loc.isEmpty ? key : "\(loc).\(key)", out: &out)
        }
    }

    if type == "array", let items = value as? [Any],
       let itemSchema = asStringDict(schema["items"]) {
        for (i, item) in items.enumerated() {
            checkNode(item, schema: itemSchema, loc: "\(loc)[\(i)]", out: &out)
        }
    }

    if let str = value as? String {
        if let anyEnum = schema["enum"] as? [Any] {
            let allowed = anyEnum.compactMap { $0 as? String }
            if !allowed.contains(str) {
                out.append("\(loc): '\(str)' not one of \(allowed)")
            }
        }
        if let pattern = schema["pattern"] as? String, !matchesFromStart(str, pattern: pattern) {
            out.append("\(loc): '\(str)' does not match /\(pattern)/")
        }
    }
}

func yamlTypeName(_ value: Any) -> String {
    if value is Bool { return "boolean" }
    if value is Int || value is Double { return "number" }
    if value is String { return "string" }
    if value is [Any] { return "array" }
    if asStringDict(value) != nil { return "object" }
    return String(describing: Swift.type(of: value))
}

func matchesFromStart(_ value: String, pattern: String) -> Bool {
    guard let re = try? NSRegularExpression(pattern: pattern) else { return true }
    let range = NSRange(value.startIndex..., in: value)
    guard let m = re.firstMatch(in: value, range: range) else { return false }
    return m.range.location == 0
}

func schemaFindings(_ surface: SurfaceRecord, schema: [String: Any]) -> [Finding] {
    var msgs: [String] = []
    checkNode(surface.data, schema: schema, loc: "", out: &msgs)
    return msgs.map { Finding(.warn, surface.id, $0) }
}

// ── code anchor + screenshot resolution ─────────────────────────────────────

func anchorFindings(_ surface: SurfaceRecord, cfg: Config) -> [Finding] {
    let anchor = surface.codeAnchor
    guard let fileRel = anchor["file"] as? String, !fileRel.isEmpty else { return [] }
    let target = cfg.projectRoot.appendingPathComponent(fileRel)
    guard FileManager.default.fileExists(atPath: target.path) else {
        return [Finding(.error, surface.id, "code_anchor.file missing: \(fileRel)")]
    }
    guard let symbol = anchor["symbol"] as? String, !symbol.isEmpty else { return [] }
    guard let text = try? String(contentsOf: target, encoding: .utf8) else {
        return [Finding(.warn, surface.id, "could not read \(fileRel)")]
    }
    let escaped = NSRegularExpression.escapedPattern(for: symbol)
    let re = try? NSRegularExpression(pattern: "\\b\(escaped)\\b")
    let found = re?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    if !found {
        return [Finding(.warn, surface.id, "code_anchor.symbol '\(symbol)' not found in \(fileRel)")]
    }
    return []
}

/// A watches entry pointing at a vanished file is a hole in the drift net —
/// same class of dead reference as a missing anchor file.
func watchesFindings(_ surface: SurfaceRecord, cfg: Config) -> [Finding] {
    surface.watches
        .filter { !FileManager.default.fileExists(atPath: cfg.projectRoot.appendingPathComponent($0).path) }
        .map { Finding(.error, surface.id, "watches file missing: \($0)") }
}

func screenshotFindings(_ surface: SurfaceRecord, cfg: Config) -> [Finding] {
    var out: [Finding] = []
    let fm = FileManager.default
    let surfaceDir = surface.path.deletingLastPathComponent()
    let searchDirs = [surfaceDir] + cfg.screenshotDirs.map {
        cfg.projectRoot.appendingPathComponent($0)
    }
    for state in surface.states {
        guard let shot = state["screenshot"] as? String, !shot.isEmpty else { continue }
        let resolved = searchDirs.contains {
            fm.fileExists(atPath: $0.appendingPathComponent(shot).path)
        } || (shot.hasPrefix("/") && fm.fileExists(atPath: shot))
        if !resolved {
            let name = state["name"] as? String ?? "?"
            out.append(Finding(.warn, surface.id, "state '\(name)' screenshot unresolved: \(shot)"))
        }
    }
    return out
}

// ── entrypoint ───────────────────────────────────────────────────────────────

public func loadSchema(_ cfg: Config) -> ([String: Any]?, Finding?) {
    guard FileManager.default.fileExists(atPath: cfg.schemaPath.path) else { return (nil, nil) }
    do {
        let data = try Data(contentsOf: cfg.schemaPath)
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any] else {
            return (nil, Finding(.warn, "-", "could not load schema: not a JSON object"))
        }
        return (dict, nil)
    } catch {
        return (nil, Finding(.warn, "-", "could not load schema: \(error.localizedDescription)"))
    }
}

public func validate(_ surfaces: [SurfaceRecord], cfg: Config) -> [Finding] {
    var findings: [Finding] = []

    let (schema, schemaLoadFinding) = loadSchema(cfg)
    if let schemaLoadFinding { findings.append(schemaLoadFinding) }

    for s in surfaces {
        if let schema { findings += schemaFindings(s, schema: schema) }
        findings += anchorFindings(s, cfg: cfg)
        findings += watchesFindings(s, cfg: cfg)
        findings += screenshotFindings(s, cfg: cfg)
    }

    let links = buildLinks(surfaces)
    for d in links.dangling {
        findings.append(Finding(
            .error, d.fromID,
            "dangling \(d.kind) -> '\(d.to)' (no such surface) [\(d.ref)]"
        ))
    }
    return findings
}
