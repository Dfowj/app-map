"""Render records -> static HTML in app-map/rendered/ (gitignored build output).

Per-surface pages (frontmatter + outgoing edges as links + derived incoming
backlinks + body prose) and a searchable index. Plain stdlib string templating;
no framework, no diagram.
"""

from __future__ import annotations

import html
import re
from pathlib import Path
from typing import Any

from .config import Config
from .links import LinkGraph
from .model import Surface

_CSS = """
:root { --fg:#1a1a1a; --mut:#6b7280; --acc:#2563eb; --bd:#e5e7eb; --warn:#b45309; --bg:#fff; }
* { box-sizing:border-box; }
body { font:15px/1.55 -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif; color:var(--fg);
       background:var(--bg); margin:0; }
.wrap { max-width:820px; margin:0 auto; padding:2rem 1.5rem 5rem; }
a { color:var(--acc); text-decoration:none; } a:hover { text-decoration:underline; }
h1 { margin:0 0 .25rem; font-size:1.5rem; } h2 { font-size:1.05rem; margin:1.75rem 0 .5rem;
     border-bottom:1px solid var(--bd); padding-bottom:.25rem; }
.kind { display:inline-block; font-size:.72rem; letter-spacing:.04em; text-transform:uppercase;
        color:var(--mut); border:1px solid var(--bd); border-radius:99px; padding:.05rem .5rem; }
.badge { font-size:.72rem; border-radius:99px; padding:.05rem .5rem; }
.badge.review { background:#fef3c7; color:var(--warn); }
.mut { color:var(--mut); }
.note { color:var(--mut); font-style:italic; }
ul.clean { list-style:none; padding:0; margin:.25rem 0; }
ul.clean li { padding:.35rem 0; border-bottom:1px solid var(--bd); }
code { background:#f3f4f6; padding:.05rem .3rem; border-radius:4px; font-size:.85em; }
.search { width:100%; padding:.6rem .8rem; font-size:1rem; border:1px solid var(--bd);
          border-radius:8px; margin:.5rem 0 1rem; }
.via { font-size:.75rem; color:var(--mut); }
.prose { margin-top:.5rem; }
img.shot { max-width:220px; border:1px solid var(--bd); border-radius:8px; display:block; margin:.4rem 0; }
.warnbox { background:#fffbeb; border:1px solid #fde68a; border-radius:8px; padding:.6rem .9rem; margin:.5rem 0; }
"""


def _esc(s: Any) -> str:
    return html.escape(str(s), quote=True)


def _mini_markdown(body: str) -> str:
    """Very small markdown -> HTML: headings, blank-line paragraphs, `code`,
    **bold**, and `- ` bullet lists. Anything else passes through escaped."""
    lines = body.splitlines()
    out: list[str] = []
    in_list = False

    def inline(t: str) -> str:
        t = _esc(t)
        t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
        t = re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
        return t

    para: list[str] = []

    def flush_para() -> None:
        if para:
            out.append("<p>" + inline(" ".join(para)) + "</p>")
            para.clear()

    for ln in lines:
        m = re.match(r"^(#{1,6})\s+(.*)$", ln)
        if m:
            flush_para()
            if in_list:
                out.append("</ul>"); in_list = False
            lvl = min(len(m.group(1)) + 1, 6)  # bump so page <h1> stays unique
            out.append(f"<h{lvl}>{inline(m.group(2))}</h{lvl}>")
            continue
        if ln.strip().startswith("- "):
            flush_para()
            if not in_list:
                out.append("<ul>"); in_list = True
            out.append("<li>" + inline(ln.strip()[2:]) + "</li>")
            continue
        if not ln.strip():
            flush_para()
            if in_list:
                out.append("</ul>"); in_list = False
            continue
        para.append(ln.strip())
    flush_para()
    if in_list:
        out.append("</ul>")
    return "\n".join(out)


def _page(title: str, inner: str) -> str:
    return (
        "<!doctype html><html lang='en'><head><meta charset='utf-8'>"
        "<meta name='viewport' content='width=device-width,initial-scale=1'>"
        f"<title>{_esc(title)}</title><style>{_CSS}</style></head>"
        f"<body><div class='wrap'>{inner}</div></body></html>"
    )


def _surface_filename(sid: str) -> str:
    return f"surface.{sid}.html"


def _render_surface(s: Surface, links: LinkGraph, ids: set[str], cfg: Config) -> str:
    def link(sid: str) -> str:
        if sid in ids:
            return f"<a href='{_surface_filename(sid)}'>{_esc(sid)}</a>"
        return f"<span class='mut'>{_esc(sid)} (missing)</span>"

    parts: list[str] = ["<p><a href='index.html'>&larr; index</a></p>"]
    review = " <span class='badge review'>needs review</span>" if s.needs_review else ""
    parts.append(f"<h1>{_esc(s.title)}{review}</h1>")
    parts.append(f"<span class='kind'>{_esc(s.kind)}</span> <span class='mut'>{_esc(s.id)}</span>")

    anchor = s.code_anchor
    if anchor:
        sym = f" &middot; <code>{_esc(anchor.get('symbol'))}</code>" if anchor.get("symbol") else ""
        parts.append(f"<p class='mut'>{_esc(anchor.get('file',''))}{sym}</p>")

    if s.contains:
        parts.append("<h2>Contains</h2><ul class='clean'>")
        for c in s.contains:
            parts.append(f"<li>{link(c)}</li>")
        parts.append("</ul>")

    if s.edges:
        parts.append("<h2>Navigates to</h2><ul class='clean'>")
        for e in s.edges:
            via = " &middot; ".join(
                _esc(x) for x in [e.get("via"), e.get("presentation")] if x
            )
            trig = f" &mdash; {_esc(e.get('trigger'))}" if e.get("trigger") else ""
            note = f"<div class='note'>{_esc(e.get('note'))}</div>" if e.get("note") else ""
            via_html = f" <span class='via'>{via}</span>" if via else ""
            parts.append(f"<li>{link(e.get('to',''))}{via_html}{trig}{note}</li>")
        parts.append("</ul>")

    incoming = links.incoming.get(s.id, [])
    if incoming:
        parts.append("<h2>Reached from</h2><ul class='clean'>")
        for inc in incoming:
            trig = f" &mdash; {_esc(inc.edge.get('trigger'))}" if inc.edge.get("trigger") else ""
            parts.append(f"<li>{link(inc.from_id)}{trig}</li>")
        parts.append("</ul>")

    if s.entry_points:
        parts.append("<h2>Entry points</h2><ul class='clean'>")
        for ep in s.entry_points:
            val = f" <code>{_esc(ep.get('value'))}</code>" if ep.get("value") else ""
            note = f" <span class='note'>{_esc(ep.get('note'))}</span>" if ep.get("note") else ""
            parts.append(f"<li><strong>{_esc(ep.get('type','?'))}</strong>{val}{note}</li>")
        parts.append("</ul>")

    if s.states:
        parts.append("<h2>States</h2><ul class='clean'>")
        surface_dir = s.path.parent
        for st in s.states:
            shot = st.get("screenshot")
            img = ""
            if shot and (surface_dir / shot).is_file():
                img = f"<img class='shot' src='../surfaces/{_esc(s.id)}/{_esc(shot)}' alt=''>"
            elif shot:
                img = f"<div class='mut'>({_esc(shot)} unresolved)</div>"
            note = f" <span class='note'>{_esc(st.get('note'))}</span>" if st.get("note") else ""
            parts.append(f"<li><strong>{_esc(st.get('name','?'))}</strong>{note}{img}</li>")
        parts.append("</ul>")

    deps = s.data.get("dependencies") or {}
    if deps:
        parts.append("<h2>Dependencies</h2><ul class='clean'>")
        for ext in deps.get("external", []) or []:
            parts.append(f"<li><span class='via'>external</span> {_esc(ext)}</li>")
        for d in deps.get("data", []) or []:
            note = f" <span class='note'>{_esc(d.get('note'))}</span>" if d.get("note") else ""
            parts.append(
                f"<li><span class='via'>{_esc(d.get('type','data'))}</span> {_esc(d.get('name',''))}{note}</li>"
            )
        parts.append("</ul>")

    if s.body.strip():
        parts.append("<h2>Notes</h2><div class='prose'>" + _mini_markdown(s.body) + "</div>")

    lv = s.last_verified
    if lv:
        parts.append(
            f"<p class='mut' style='margin-top:2rem'>last verified {_esc(lv.get('sha','?'))} &middot; {_esc(lv.get('date','?'))}</p>"
        )

    return _page(s.title, "".join(parts))


def _render_index(surfaces: list[Surface], links: LinkGraph, cfg: Config) -> str:
    parts: list[str] = ["<h1>App Map</h1>"]
    root = cfg.launch_surface
    if root:
        parts.append(f"<p class='mut'>launch surface: <code>{_esc(root)}</code></p>")

    review = [s.id for s in surfaces if s.needs_review]
    if review:
        parts.append(
            "<div class='warnbox'><strong>Review queue:</strong> "
            + ", ".join(_esc(r) for r in review) + "</div>"
        )
    if links.dangling:
        items = ", ".join(f"{_esc(d.from_id)}&rarr;{_esc(d.to)}" for d in links.dangling)
        parts.append(f"<div class='warnbox'><strong>Broken links:</strong> {items}</div>")

    parts.append("<input class='search' id='q' placeholder='Filter surfaces…' autofocus>")
    parts.append("<ul class='clean' id='list'>")
    for s in surfaces:
        review_badge = " <span class='badge review'>review</span>" if s.needs_review else ""
        anchor = s.code_anchor.get("file", "")
        parts.append(
            f"<li data-k='{_esc(s.id)} {_esc(s.title)} {_esc(s.kind)} {_esc(anchor)}'>"
            f"<a href='{_surface_filename(s.id)}'>{_esc(s.title)}</a> "
            f"<span class='kind'>{_esc(s.kind)}</span>{review_badge}"
            f"<div class='mut' style='font-size:.8rem'>{_esc(anchor)}</div></li>"
        )
    parts.append("</ul>")
    parts.append(
        "<script>const q=document.getElementById('q'),items=[...document.querySelectorAll('#list li')];"
        "q.addEventListener('input',()=>{const v=q.value.toLowerCase();"
        "items.forEach(li=>{li.style.display=li.dataset.k.toLowerCase().includes(v)?'':'none';});});</script>"
    )
    return _page("App Map", "".join(parts))


def render_map(surfaces: list[Surface], links: LinkGraph, cfg: Config) -> Path:
    out_dir = cfg.rendered_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    ids = {s.id for s in surfaces}
    (out_dir / "index.html").write_text(_render_index(surfaces, links, cfg), encoding="utf-8")
    for s in surfaces:
        (out_dir / _surface_filename(s.id)).write_text(
            _render_surface(s, links, ids, cfg), encoding="utf-8"
        )
    return out_dir
