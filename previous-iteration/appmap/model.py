"""Surface records: parse/serialize frontmatter, load a whole map.

A surface record (`surfaces/<id>/surface.md`) is YAML frontmatter between `---`
fences followed by a markdown body. The frontmatter carries tier-1 (script) and
tier-2 (agent) fields; the **body is tier-3 (human) prose and is preserved
verbatim** — we never rewrite it as a side effect of compute.
"""

from __future__ import annotations

import datetime as _dt
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

FENCE = "---"


@dataclass
class Surface:
    """One surface record. `data` is the raw frontmatter dict; `body` is the
    verbatim markdown after the second fence."""

    path: Path
    data: dict[str, Any] = field(default_factory=dict)
    body: str = ""

    # ── tier-2/manual accessors (read-only convenience) ──────────────────
    @property
    def id(self) -> str:
        return self.data.get("id", self.path.parent.name)

    @property
    def title(self) -> str:
        return self.data.get("title", self.id)

    @property
    def kind(self) -> str:
        return self.data.get("kind", "screen")

    @property
    def contains(self) -> list[str]:
        return list(self.data.get("contains") or [])

    @property
    def edges(self) -> list[dict[str, Any]]:
        return list(self.data.get("edges") or [])

    @property
    def entry_points(self) -> list[dict[str, Any]]:
        return list(self.data.get("entry_points") or [])

    @property
    def states(self) -> list[dict[str, Any]]:
        return list(self.data.get("states") or [])

    @property
    def code_anchor(self) -> dict[str, Any]:
        return dict(self.data.get("code_anchor") or {})

    @property
    def needs_review(self) -> bool:
        return bool(self.data.get("needs_review", False))

    @property
    def last_verified(self) -> dict[str, Any]:
        return dict(self.data.get("last_verified") or {})

    # ── serialization ────────────────────────────────────────────────────
    def dumps(self) -> str:
        """Serialize back to `---`-fenced frontmatter + body. Body is emitted
        verbatim so tier-3 prose round-trips exactly."""
        head = yaml.safe_dump(
            self.data, sort_keys=False, allow_unicode=True, default_flow_style=False
        ).rstrip("\n")
        body = self.body if self.body.startswith("\n") else "\n" + self.body
        return f"{FENCE}\n{head}\n{FENCE}\n{body.lstrip(chr(10))}"

    def write(self) -> None:
        self.path.write_text(self.dumps(), encoding="utf-8")


def parse_surface(path: Path) -> Surface:
    """Parse a surface.md file into a Surface. Tolerant: a file with no
    frontmatter yields an empty `data` and the whole text as `body`."""
    text = path.read_text(encoding="utf-8")
    data: dict[str, Any] = {}
    body = text
    if text.lstrip().startswith(FENCE):
        # split into ['', <yaml>, <body...>]
        stripped = text.lstrip()
        parts = stripped.split(FENCE, 2)
        if len(parts) == 3:
            _, raw_yaml, body = parts
            loaded = yaml.safe_load(raw_yaml) or {}
            if isinstance(loaded, dict):
                data = loaded
            body = body.lstrip("\n")
    return Surface(path=path, data=data, body=body)


def load_surfaces(surfaces_dir: Path) -> list[Surface]:
    """Load every `surfaces/*/surface.md`, sorted by id for stable output."""
    out: list[Surface] = []
    if not surfaces_dir.is_dir():
        return out
    for surface_md in sorted(surfaces_dir.glob("*/surface.md")):
        out.append(parse_surface(surface_md))
    out.sort(key=lambda s: s.id)
    return out


def today() -> str:
    return _dt.date.today().isoformat()
