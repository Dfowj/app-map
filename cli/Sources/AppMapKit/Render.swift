// Render records -> static HTML in app-map/rendered/ (gitignored build
// output). Three page types, all self-contained (inline CSS/JS, no external
// requests) and deterministic — same records, same bytes:
//   index.html         searchable surface directory
//   map.html           navigation-graph overview (layered SVG)
//   surface.<id>.html  one page per surface
//
// Written for two audiences at once: a PM answering "what does Cart connect
// to, and what does it look like when it's empty?", and a dev chasing the
// code anchor.

import Foundation

// ── shared chrome ────────────────────────────────────────────────────────────

let css = """
:root { --fg:#18181b; --mut:#71717a; --acc:#2563eb; --bd:#e4e4e7; --bg:#fff; --card:#fafafa;
        --warn-bg:#fffbeb; --warn-bd:#fde68a; --warn-fg:#b45309; }
* { box-sizing:border-box; }
body { font:15px/1.55 -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif; color:var(--fg);
       background:var(--bg); margin:0; }
.wrap { max-width:880px; margin:0 auto; padding:1.25rem 1.5rem 5rem; }
a { color:var(--acc); text-decoration:none; } a:hover { text-decoration:underline; }
nav.top { display:flex; gap:1rem; align-items:baseline; border-bottom:1px solid var(--bd);
          padding:.4rem 0 .6rem; margin-bottom:1.5rem; font-size:.9rem; }
nav.top .brand { font-weight:650; color:var(--fg); }
h1 { margin:0 0 .3rem; font-size:1.55rem; letter-spacing:-.01em; }
h2 { font-size:.95rem; margin:1.9rem 0 .5rem; text-transform:uppercase; letter-spacing:.06em;
     color:var(--mut); border-bottom:1px solid var(--bd); padding-bottom:.3rem; }
.kind { display:inline-block; font-size:.7rem; font-weight:600; letter-spacing:.05em;
        text-transform:uppercase; border-radius:99px; padding:.1rem .55rem; white-space:nowrap; }
.kind.screen { background:#dbeafe; color:#1d4ed8; } .kind.tab-root { background:#dcfce7; color:#15803d; }
.kind.tab-bar { background:#f3e8ff; color:#7e22ce; } .kind.sheet { background:#ffedd5; color:#c2410c; }
.kind.modal { background:#fee2e2; color:#b91c1c; } .kind.popover { background:#ccfbf1; color:#0f766e; }
.kind.container { background:#f4f4f5; color:#52525b; }
.badge.review { font-size:.7rem; font-weight:600; border-radius:99px; padding:.1rem .55rem;
                background:var(--warn-bg); color:var(--warn-fg); border:1px solid var(--warn-bd); }
.mut { color:var(--mut); } .note { color:var(--mut); font-style:italic; }
ul.clean { list-style:none; padding:0; margin:.25rem 0; }
ul.clean li { padding:.45rem 0; border-bottom:1px solid var(--bd); }
code { background:#f4f4f5; padding:.08rem .35rem; border-radius:4px; font-size:.85em; }
.search { width:100%; padding:.6rem .8rem; font-size:1rem; border:1px solid var(--bd);
          border-radius:8px; margin:.75rem 0 1rem; background:var(--bg); color:var(--fg); }
.via { font-size:.75rem; color:var(--mut); }
.prose { margin:.75rem 0 0; max-width:44rem; }
.prose h2 { text-transform:none; letter-spacing:0; font-size:1.05rem; color:var(--fg); }
img.shot { max-width:220px; border:1px solid var(--bd); border-radius:8px; display:block; margin:.4rem 0; }
.warnbox { background:var(--warn-bg); border:1px solid var(--warn-bd); border-radius:8px;
           padding:.6rem .9rem; margin:.5rem 0; font-size:.9rem; }
.stats { display:flex; gap:1.75rem; flex-wrap:wrap; margin:1rem 0 .25rem; }
.stat b { display:block; font-size:1.3rem; } .stat span { font-size:.78rem; color:var(--mut);
          text-transform:uppercase; letter-spacing:.05em; }
li.card { display:grid; grid-template-columns:1fr auto; gap:.15rem 1rem; }
li.card .snippet { grid-column:1/-1; font-size:.86rem; color:var(--mut); max-width:40rem; }
li.card .meta { font-size:.78rem; color:var(--mut); }
.graphwrap { overflow-x:auto; border:1px solid var(--bd); border-radius:10px; background:var(--card); }
.legend { display:flex; gap:1.1rem; flex-wrap:wrap; font-size:.78rem; color:var(--mut); margin:.6rem 0 1rem; }
.legend .sw { display:inline-block; width:18px; height:0; border-top:2px solid #94a3b8;
              vertical-align:middle; margin-right:.3rem; }
.legend .sw.contain { border-top-style:dashed; }
footer.stamp { margin-top:2.5rem; font-size:.8rem; color:var(--mut); }
@media (prefers-color-scheme: dark) {
  :root { --fg:#e4e4e7; --mut:#a1a1aa; --acc:#60a5fa; --bd:#27272a; --bg:#111113; --card:#18181b;
          --warn-bg:#292215; --warn-bd:#57431a; --warn-fg:#fbbf24; }
  code { background:#27272a; }
  .kind.screen { background:#1e3a5f; color:#93c5fd; } .kind.tab-root { background:#14352a; color:#86efac; }
  .kind.tab-bar { background:#372554; color:#d8b4fe; } .kind.sheet { background:#43250e; color:#fdba74; }
  .kind.modal { background:#450f0f; color:#fca5a5; } .kind.popover { background:#0e3733; color:#5eead4; }
  .kind.container { background:#27272a; color:#a1a1aa; }
}
"""

func esc(_ s: Any?) -> String {
    guard let s else { return "" }
    return "\(s)"
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}

func page(title: String, nav: String, inner: String) -> String {
    """
    <!doctype html><html lang='en'><head><meta charset='utf-8'>
    <meta name='viewport' content='width=device-width,initial-scale=1'>
    <title>\(esc(title))</title><style>\(css)</style></head>
    <body><div class='wrap'>\(nav)\(inner)</div></body></html>
    """
}

func topNav(active: String) -> String {
    func item(_ label: String, _ href: String) -> String {
        active == label
            ? "<span class='mut'>\(label)</span>"
            : "<a href='\(href)'>\(label)</a>"
    }
    return "<nav class='top'><span class='brand'>App Map</span>"
        + item("surfaces", "index.html") + item("graph", "map.html") + "</nav>"
}

func surfaceFilename(_ id: String) -> String { "surface.\(id).html" }

func kindBadge(_ kind: String) -> String {
    let cls = ["screen", "tab-root", "tab-bar", "sheet", "modal", "popover", "container"]
        .contains(kind) ? kind : "container"
    return "<span class='kind \(cls)'>\(esc(kind))</span>"
}

// ── mini markdown (headings, paragraphs, bullets, **bold**, `code`) ─────────

func miniMarkdown(_ body: String) -> String {
    func inline(_ t: String) -> String {
        var s = esc(t)
        s = s.replacingOccurrences(
            of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        s = s.replacingOccurrences(
            of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)
        return s
    }

    var out: [String] = []
    var para: [String] = []
    var inList = false

    func flushPara() {
        if !para.isEmpty {
            out.append("<p>" + inline(para.joined(separator: " ")) + "</p>")
            para.removeAll()
        }
    }
    func closeList() {
        if inList { out.append("</ul>"); inList = false }
    }

    for line in body.components(separatedBy: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if let m = line.range(of: "^(#{1,6})\\s+", options: .regularExpression) {
            flushPara(); closeList()
            let hashes = line[m].trimmingCharacters(in: .whitespaces).count
            let level = min(hashes + 1, 6)  // bump so the page <h1> stays unique
            out.append("<h\(level)>\(inline(String(line[m.upperBound...])))</h\(level)>")
            continue
        }
        if trimmed.hasPrefix("- ") {
            flushPara()
            if !inList { out.append("<ul>"); inList = true }
            out.append("<li>" + inline(String(trimmed.dropFirst(2))) + "</li>")
            continue
        }
        if trimmed.isEmpty {
            flushPara(); closeList()
            continue
        }
        para.append(trimmed)
    }
    flushPara(); closeList()
    return out.joined(separator: "\n")
}

/// First prose paragraph of the body (skipping headings) — the one-line gloss
/// shown on the index and graph tooltips.
func bodySnippet(_ body: String, limit: Int = 180) -> String {
    var para: [String] = []
    for line in body.components(separatedBy: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") { continue }
        if trimmed.isEmpty {
            if !para.isEmpty { break }
            continue
        }
        para.append(trimmed)
    }
    var text = para.joined(separator: " ")
        .replacingOccurrences(of: "**", with: "")
        .replacingOccurrences(of: "`", with: "")
    if text.count > limit {
        text = String(text.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }
    return text
}

// ── screenshot resolution (for <img> hrefs relative to rendered/) ───────────

func screenshotHref(_ shot: String, surface: SurfaceRecord, cfg: Config) -> String? {
    let fm = FileManager.default
    let surfaceDir = surface.path.deletingLastPathComponent()
    if fm.fileExists(atPath: surfaceDir.appendingPathComponent(shot).path) {
        return "../surfaces/\(surface.id)/\(shot)"
    }
    for dir in cfg.screenshotDirs
    where fm.fileExists(atPath: cfg.projectRoot.appendingPathComponent(dir)
        .appendingPathComponent(shot).path) {
        return "../../\(dir)/\(shot)"
    }
    return nil
}

// ── surface page ─────────────────────────────────────────────────────────────

func renderSurfacePage(
    _ s: SurfaceRecord, surfaces: [SurfaceRecord], links: LinkGraph, cfg: Config
) -> String {
    let ids = Set(surfaces.map(\.id))
    func link(_ sid: String) -> String {
        ids.contains(sid)
            ? "<a href='\(surfaceFilename(sid))'>\(esc(sid))</a>"
            : "<span class='mut'>\(esc(sid)) (missing)</span>"
    }

    var parts: [String] = []
    let review = s.needsReview ? " <span class='badge review'>needs review</span>" : ""
    parts.append("<h1>\(esc(s.title))\(review)</h1>")
    parts.append("<p>\(kindBadge(s.kind)) <span class='mut'>\(esc(s.id))</span></p>")

    let anchor = s.codeAnchor
    if let file = anchor["file"] as? String {
        let sym = (anchor["symbol"] as? String).map { " &middot; <code>\(esc($0))</code>" } ?? ""
        parts.append("<p class='mut'><code>\(esc(file))</code>\(sym)</p>")
    }
    if !s.watches.isEmpty {
        let files = s.watches.map { "<code>\(esc($0))</code>" }.joined(separator: ", ")
        parts.append("<p class='mut'><span class='via'>also watches</span> \(files)</p>")
    }

    if !s.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        parts.append("<div class='prose'>" + miniMarkdown(s.body) + "</div>")
    }

    if !s.contains.isEmpty {
        parts.append("<h2>Contains</h2><ul class='clean'>")
        parts.append(contentsOf: s.contains.map { "<li>\(link($0))</li>" })
        parts.append("</ul>")
    }

    let containedBy = surfaces.filter { $0.contains.contains(s.id) }.map(\.id)
    if !containedBy.isEmpty {
        parts.append("<h2>Contained by</h2><ul class='clean'>")
        parts.append(contentsOf: containedBy.map { "<li>\(link($0))</li>" })
        parts.append("</ul>")
    }

    if !s.edges.isEmpty {
        parts.append("<h2>Navigates to</h2><ul class='clean'>")
        for e in s.edges {
            let via = [e["via"] as? String, e["presentation"] as? String]
                .compactMap { $0 }.map(esc).joined(separator: " &middot; ")
            let viaHTML = via.isEmpty ? "" : " <span class='via'>\(via)</span>"
            let trig = (e["trigger"] as? String).map { " &mdash; \(esc($0))" } ?? ""
            let note = (e["note"] as? String).map { "<div class='note'>\(esc($0))</div>" } ?? ""
            parts.append("<li>\(link(e["to"] as? String ?? ""))\(viaHTML)\(trig)\(note)</li>")
        }
        parts.append("</ul>")
    }

    let incoming = links.incoming[s.id] ?? []
    if !incoming.isEmpty {
        parts.append("<h2>Reached from</h2><ul class='clean'>")
        for inc in incoming {
            let trig = (inc.edge["trigger"] as? String).map { " &mdash; \(esc($0))" } ?? ""
            parts.append("<li>\(link(inc.fromID))\(trig)</li>")
        }
        parts.append("</ul>")
    }

    if !s.entryPoints.isEmpty {
        parts.append("<h2>Entry points</h2><ul class='clean'>")
        for ep in s.entryPoints {
            let val = (ep["value"] as? String).map { " <code>\(esc($0))</code>" } ?? ""
            let note = (ep["note"] as? String).map { " <span class='note'>\(esc($0))</span>" } ?? ""
            parts.append("<li><strong>\(esc(ep["type"] as? String ?? "?"))</strong>\(val)\(note)</li>")
        }
        parts.append("</ul>")
    }

    if !s.states.isEmpty {
        parts.append("<h2>States</h2><ul class='clean'>")
        for st in s.states {
            let note = (st["note"] as? String).map { " <span class='note'>\(esc($0))</span>" } ?? ""
            var img = ""
            if let shot = st["screenshot"] as? String {
                if let href = screenshotHref(shot, surface: s, cfg: cfg) {
                    img = "<img class='shot' src='\(esc(href))' alt='\(esc(st["name"] as? String ?? ""))'>"
                } else {
                    img = "<div class='mut'>(\(esc(shot)) unresolved)</div>"
                }
            }
            parts.append("<li><strong>\(esc(st["name"] as? String ?? "?"))</strong>\(note)\(img)</li>")
        }
        parts.append("</ul>")
    }

    let deps = s.dependencies
    if !deps.isEmpty {
        parts.append("<h2>Dependencies</h2><ul class='clean'>")
        for ext in (deps["external"] as? [Any])?.compactMap({ $0 as? String }) ?? [] {
            parts.append("<li><span class='via'>external</span> \(esc(ext))</li>")
        }
        for d in (deps["data"] as? [Any])?.compactMap({ asStringDict($0) }) ?? [] {
            let note = (d["note"] as? String).map { " <span class='note'>\(esc($0))</span>" } ?? ""
            parts.append(
                "<li><span class='via'>\(esc(d["type"] as? String ?? "data"))</span> "
                + "\(esc(d["name"] as? String ?? ""))\(note)</li>")
        }
        parts.append("</ul>")
    }

    let lv = s.lastVerified
    if !lv.isEmpty {
        parts.append(
            "<footer class='stamp'>last verified \(esc(lv["sha"] ?? "?")) &middot; "
            + "\(esc(lv["date"] ?? "?"))</footer>")
    }

    return page(title: s.title, nav: topNav(active: ""), inner: parts.joined())
}

// ── index page ───────────────────────────────────────────────────────────────

func renderIndex(_ surfaces: [SurfaceRecord], links: LinkGraph, cfg: Config) -> String {
    var parts: [String] = ["<h1>App Map</h1>"]

    var kindCounts: [String: Int] = [:]
    for s in surfaces { kindCounts[s.kind, default: 0] += 1 }
    let kindSummary = kindCounts.sorted { $0.key < $1.key }
        .map { "\($0.value) \(esc($0.key))" }.joined(separator: " &middot; ")
    let launch = cfg.launchSurface.map { " &middot; launch: <code>\(esc($0))</code>" } ?? ""
    parts.append("<p class='mut'>\(surfaces.count) surfaces (\(kindSummary))\(launch)</p>")

    let review = surfaces.filter(\.needsReview).map(\.id)
    if !review.isEmpty {
        parts.append(
            "<div class='warnbox'><strong>Review queue:</strong> "
            + review.map { "<a href='\(surfaceFilename($0))'>\(esc($0))</a>" }
                .joined(separator: ", ") + "</div>")
    }
    if !links.dangling.isEmpty {
        let items = links.dangling
            .map { "\(esc($0.fromID))&rarr;\(esc($0.to)) <span class='via'>(\(esc($0.kind)))</span>" }
            .joined(separator: ", ")
        parts.append("<div class='warnbox'><strong>Broken links:</strong> \(items)</div>")
    }

    parts.append(
        "<input class='search' id='q' placeholder='Filter surfaces by name, kind, file…' autofocus>")
    parts.append("<ul class='clean' id='list'>")
    for s in surfaces {
        let reviewBadge = s.needsReview ? " <span class='badge review'>review</span>" : ""
        let anchor = s.codeAnchor["file"] as? String ?? ""
        let snippet = bodySnippet(s.body)
        let out = s.edges.count
        let inn = (links.incoming[s.id] ?? []).count
        let key = "\(s.id) \(s.title) \(s.kind) \(anchor) \(snippet)"
        parts.append("""
        <li class='card' data-k='\(esc(key.lowercased()))'>
        <span><a href='\(surfaceFilename(s.id))'><strong>\(esc(s.title))</strong></a> \
        \(kindBadge(s.kind))\(reviewBadge)</span>
        <span class='meta'>\(out) out &middot; \(inn) in</span>
        \(snippet.isEmpty ? "" : "<span class='snippet'>\(esc(snippet))</span>")
        <span class='meta'>\(esc(anchor))</span></li>
        """)
    }
    parts.append("</ul>")
    parts.append("""
    <script>const q=document.getElementById('q'),items=[...document.querySelectorAll('#list li')];
    q.addEventListener('input',()=>{const v=q.value.toLowerCase();
    items.forEach(li=>{li.style.display=li.dataset.k.includes(v)?'':'none';});});</script>
    """)
    return page(title: "App Map", nav: topNav(active: "surfaces"), inner: parts.joined())
}

// ── graph page ───────────────────────────────────────────────────────────────
//
// Deterministic layered layout: BFS from the launch surface (else from
// surfaces nobody links to) over containment + navigation edges; column =
// BFS depth, nodes id-sorted within a column. No physics, no randomness.

struct GraphNode {
    let id: String
    var col: Int
    var row: Int
    var x: Double { Double(col) * 230 + 20 }
    var y: Double { Double(row) * 78 + 20 }
}

func layoutGraph(_ surfaces: [SurfaceRecord]) -> [String: GraphNode] {
    let ids = surfaces.map(\.id)
    let idSet = Set(ids)
    var adjacency: [String: [String]] = [:]
    var hasIncoming = Set<String>()
    for s in surfaces {
        var targets = s.contains.filter { idSet.contains($0) }
        targets += s.edges.compactMap { $0["to"] as? String }.filter { idSet.contains($0) }
        adjacency[s.id] = targets
        for t in targets where t != s.id { hasIncoming.insert(t) }
    }

    var roots = ids.filter { !hasIncoming.contains($0) }.sorted()
    if roots.isEmpty, let first = ids.sorted().first { roots = [first] }

    var depth: [String: Int] = [:]
    var queue = roots
    for r in roots { depth[r] = 0 }
    while !queue.isEmpty {
        let cur = queue.removeFirst()
        for next in (adjacency[cur] ?? []).sorted() where depth[next] == nil {
            depth[next] = (depth[cur] ?? 0) + 1
            queue.append(next)
        }
    }
    let maxDepth = depth.values.max() ?? 0
    for id in ids where depth[id] == nil { depth[id] = maxDepth + 1 }  // unreached column

    var byCol: [Int: [String]] = [:]
    for (id, d) in depth { byCol[d, default: []].append(id) }
    var nodes: [String: GraphNode] = [:]
    for (col, colIDs) in byCol {
        for (row, id) in colIDs.sorted().enumerated() {
            nodes[id] = GraphNode(id: id, col: col, row: row)
        }
    }
    return nodes
}

func renderGraph(_ surfaces: [SurfaceRecord], links: LinkGraph, cfg: Config) -> String {
    let nodes = layoutGraph(surfaces)
    let byID = Dictionary(uniqueKeysWithValues: surfaces.map { ($0.id, $0) })
    let nodeW = 178.0, nodeH = 52.0
    let width = (nodes.values.map(\.x).max() ?? 0) + nodeW + 40
    let height = (nodes.values.map(\.y).max() ?? 0) + nodeH + 40

    var svg: [String] = []
    svg.append("""
    <svg viewBox='0 0 \(Int(width)) \(Int(height))' width='\(Int(width))' \
    xmlns='http://www.w3.org/2000/svg' font-family='-apple-system,BlinkMacSystemFont,sans-serif'>
    <defs><marker id='arrow' viewBox='0 0 10 10' refX='9' refY='5' markerWidth='7' \
    markerHeight='7' orient='auto-start-reverse'>
    <path d='M 0 0 L 10 5 L 0 10 z' fill='#94a3b8'/></marker></defs>
    """)

    func edgePath(from a: GraphNode, to b: GraphNode) -> String {
        let x1 = a.x + nodeW, y1 = a.y + nodeH / 2
        let x2 = b.x, y2 = b.y + nodeH / 2
        if b.col > a.col {
            let mid = (x1 + x2) / 2
            return "M \(x1) \(y1) C \(mid) \(y1), \(mid) \(y2), \(x2) \(y2)"
        }
        // backward or same-column edge: arc from the left side of the source
        let sx = a.x, tx = b.x + nodeW
        let bend = min(sx, tx) - 60
        return "M \(sx) \(y1) C \(bend) \(y1), \(bend) \(y2), \(tx) \(y2)"
    }

    for s in surfaces.sorted(by: { $0.id < $1.id }) {
        guard let from = nodes[s.id] else { continue }
        for child in s.contains {
            guard let to = nodes[child] else { continue }
            svg.append(
                "<path d='\(edgePath(from: from, to: to))' fill='none' stroke='#94a3b8' "
                + "stroke-width='1.4' stroke-dasharray='5 4'>"
                + "<title>\(esc(s.id)) contains \(esc(child))</title></path>")
        }
        for e in s.edges {
            guard let toID = e["to"] as? String, let to = nodes[toID] else { continue }
            let label = [e["trigger"] as? String, e["via"] as? String]
                .compactMap { $0 }.joined(separator: " · ")
            svg.append(
                "<path d='\(edgePath(from: from, to: to))' fill='none' stroke='#94a3b8' "
                + "stroke-width='1.4' marker-end='url(#arrow)'>"
                + "<title>\(esc(s.id)) → \(esc(toID))\(label.isEmpty ? "" : ": \(esc(label))")</title></path>")
        }
    }

    let fills = [
        "screen": "#dbeafe", "tab-root": "#dcfce7", "tab-bar": "#f3e8ff", "sheet": "#ffedd5",
        "modal": "#fee2e2", "popover": "#ccfbf1", "container": "#f4f4f5",
    ]
    let strokes = [
        "screen": "#1d4ed8", "tab-root": "#15803d", "tab-bar": "#7e22ce", "sheet": "#c2410c",
        "modal": "#b91c1c", "popover": "#0f766e", "container": "#52525b",
    ]

    for id in nodes.keys.sorted() {
        guard let n = nodes[id], let s = byID[id] else { continue }
        let fill = fills[s.kind] ?? fills["container"]!
        let stroke = strokes[s.kind] ?? strokes["container"]!
        var title = s.title
        if title.count > 20 { title = String(title.prefix(19)) + "…" }
        let entryGlyph = s.entryPoints.isEmpty
            ? ""
            : "<text x='\(n.x + nodeW - 14)' y='\(n.y + 18)' font-size='12'>⚡</text>"
        let snippet = bodySnippet(s.body, limit: 120)
        svg.append("""
        <a href='\(surfaceFilename(id))'>
        <rect x='\(n.x)' y='\(n.y)' width='\(nodeW)' height='\(nodeH)' rx='9' \
        fill='\(fill)' stroke='\(stroke)' stroke-width='1.3'/>
        <text x='\(n.x + 12)' y='\(n.y + 21)' font-size='13' font-weight='600' \
        fill='#18181b'>\(esc(title))</text>
        <text x='\(n.x + 12)' y='\(n.y + 38)' font-size='10' fill='\(stroke)' \
        letter-spacing='.5'>\(esc(s.kind.uppercased()))\(s.needsReview ? " · NEEDS REVIEW" : "")</text>
        \(entryGlyph)
        <title>\(esc(s.title))\(snippet.isEmpty ? "" : " — \(esc(snippet))")</title>
        </a>
        """)
    }
    svg.append("</svg>")

    var parts: [String] = ["<h1>Navigation graph</h1>"]
    parts.append(
        "<p class='mut'>Columns follow navigation depth from "
        + "\(cfg.launchSurface.map { "<code>\(esc($0))</code>" } ?? "the app's roots"); "
        + "click a surface to open its page. Hover edges for triggers.</p>")
    parts.append(
        "<div class='legend'><span><span class='sw'></span>navigates to</span>"
        + "<span><span class='sw contain'></span>contains</span>"
        + "<span>⚡ has external entry points</span></div>")
    parts.append("<div class='graphwrap'>" + svg.joined(separator: "\n") + "</div>")
    return page(title: "App Map — graph", nav: topNav(active: "graph"), inner: parts.joined())
}

// ── entrypoint ───────────────────────────────────────────────────────────────

public func renderMap(
    _ surfaces: [SurfaceRecord], links: LinkGraph, cfg: Config
) throws -> URL {
    let outDir = cfg.renderedDir
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    try renderIndex(surfaces, links: links, cfg: cfg)
        .write(to: outDir.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
    try renderGraph(surfaces, links: links, cfg: cfg)
        .write(to: outDir.appendingPathComponent("map.html"), atomically: true, encoding: .utf8)
    for s in surfaces {
        try renderSurfacePage(s, surfaces: surfaces, links: links, cfg: cfg)
            .write(
                to: outDir.appendingPathComponent(surfaceFilename(s.id)),
                atomically: true, encoding: .utf8)
    }
    return outDir
}
