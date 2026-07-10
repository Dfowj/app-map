"""Wholesale manifest.yaml build — the derived 'front door' index (tier-1).

All fields here are derived from the surface records; the manifest is safe to
regenerate at any time. Kept low-stakes on merge by being fully derived: on a
conflict, take either side and re-render.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml

from .config import Config
from .links import LinkGraph
from .model import Surface


def build_manifest(
    surfaces: list[Surface], links: LinkGraph, cfg: Config
) -> dict[str, Any]:
    index: dict[str, Any] = {}
    for s in sorted(surfaces, key=lambda s: s.id):
        lv = s.last_verified.get("sha") if s.last_verified else None
        index[s.id] = {
            "title": s.title,
            "kind": s.kind,
            "path": f"surfaces/{s.id}/surface.md",
            "last_verified": lv,
            "needs_review": s.needs_review,
        }

    review_queue = sorted(s.id for s in surfaces if s.needs_review)

    dangling = [
        {"from": d.from_id, "to": d.to, "kind": d.kind, "ref": d.ref}
        for d in links.dangling
    ]

    manifest: dict[str, Any] = {
        "launch_surface": cfg.launch_surface,
        "surfaces": index,
        "review_queue": review_queue,
        "link_health": {
            "dangling_links": dangling,
        },
    }
    return manifest


def write_manifest(manifest: dict[str, Any], cfg: Config) -> Path:
    text = yaml.safe_dump(manifest, sort_keys=False, allow_unicode=True)
    cfg.manifest_path.write_text(text, encoding="utf-8")
    return cfg.manifest_path
