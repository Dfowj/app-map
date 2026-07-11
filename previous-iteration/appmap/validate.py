"""Validation — the linter's teeth, but warn-only. Never blocks; exit 0.

Three checks:
  * frontmatter shape vs surface.schema.json (hand-rolled subset — no jsonschema dep),
  * code_anchor resolution (file exists; symbol appears in it),
  * screenshot path resolution (state screenshots resolve to a file),
plus dangling-link reporting (from links.build_links).
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .config import Config
from .links import build_links
from .model import Surface

WARN = "warn"
ERROR = "error"  # still non-blocking; severity is for the human's attention only


@dataclass
class Finding:
    level: str
    surface: str
    message: str


# ── tiny JSON-schema-subset validator (required/type/enum/pattern) ───────────

_TYPE_CHECKS = {
    "string": lambda v: isinstance(v, str),
    "boolean": lambda v: isinstance(v, bool),
    "array": lambda v: isinstance(v, list),
    "object": lambda v: isinstance(v, dict),
    "number": lambda v: isinstance(v, (int, float)) and not isinstance(v, bool),
}


def _check_node(value: Any, schema: dict[str, Any], loc: str, out: list[str]) -> None:
    t = schema.get("type")
    if t and t in _TYPE_CHECKS and value is not None and not _TYPE_CHECKS[t](value):
        out.append(f"{loc}: expected {t}, got {type(value).__name__}")
        return

    if t == "object" and isinstance(value, dict):
        for req in schema.get("required", []):
            if req not in value:
                out.append(f"{loc}: missing required '{req}'")
        props = schema.get("properties", {})
        for k, sub in props.items():
            if k in value and value[k] is not None:
                _check_node(value[k], sub, f"{loc}.{k}" if loc else k, out)

    if t == "array" and isinstance(value, list):
        item_schema = schema.get("items")
        if item_schema:
            for i, item in enumerate(value):
                _check_node(item, item_schema, f"{loc}[{i}]", out)

    if isinstance(value, str):
        enum = schema.get("enum")
        if enum and value not in enum:
            out.append(f"{loc}: '{value}' not one of {enum}")
        pat = schema.get("pattern")
        if pat and not re.match(pat, value):
            out.append(f"{loc}: '{value}' does not match /{pat}/")


def _schema_findings(surface: Surface, schema: dict[str, Any]) -> list[Finding]:
    msgs: list[str] = []
    _check_node(surface.data, schema, "", msgs)
    return [Finding(WARN, surface.id, m) for m in msgs]


# ── code anchor + screenshot resolution ──────────────────────────────────────

def _anchor_findings(surface: Surface, cfg: Config) -> list[Finding]:
    out: list[Finding] = []
    anchor = surface.code_anchor
    if not anchor:
        return out
    file_rel = anchor.get("file")
    if not file_rel:
        return out
    target = (cfg.project_root / file_rel)
    if not target.is_file():
        out.append(Finding(ERROR, surface.id, f"code_anchor.file missing: {file_rel}"))
        return out
    symbol = anchor.get("symbol")
    if symbol:
        try:
            text = target.read_text(encoding="utf-8", errors="ignore")
            if not re.search(rf"\b{re.escape(symbol)}\b", text):
                out.append(
                    Finding(WARN, surface.id, f"code_anchor.symbol '{symbol}' not found in {file_rel}")
                )
        except Exception as e:  # pragma: no cover - defensive
            out.append(Finding(WARN, surface.id, f"could not read {file_rel}: {e}"))
    return out


def _screenshot_findings(surface: Surface, cfg: Config) -> list[Finding]:
    out: list[Finding] = []
    surface_dir = surface.path.parent
    search_dirs = [surface_dir] + [cfg.project_root / d for d in cfg.screenshot_dirs]
    for st in surface.states:
        shot = st.get("screenshot")
        if not shot:
            continue
        if any((d / shot).is_file() or Path(shot).is_absolute() and Path(shot).is_file()
               for d in search_dirs):
            continue
        out.append(
            Finding(WARN, surface.id,
                    f"state '{st.get('name', '?')}' screenshot unresolved: {shot}")
        )
    return out


# ── entrypoint ───────────────────────────────────────────────────────────────

def validate(surfaces: list[Surface], cfg: Config) -> list[Finding]:
    findings: list[Finding] = []

    schema: dict[str, Any] = {}
    if cfg.schema_path.is_file():
        try:
            schema = json.loads(cfg.schema_path.read_text(encoding="utf-8"))
        except Exception as e:
            findings.append(Finding(WARN, "-", f"could not load schema: {e}"))

    for s in surfaces:
        if schema:
            findings += _schema_findings(s, schema)
        findings += _anchor_findings(s, cfg)
        findings += _screenshot_findings(s, cfg)

    links = build_links(surfaces)
    for d in links.dangling:
        findings.append(
            Finding(ERROR, d.from_id, f"dangling {d.kind} -> '{d.to}' (no such surface) [{d.ref}]")
        )

    return findings
