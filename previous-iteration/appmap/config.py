"""Locate a project's `app-map/` directory and read its config."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

MAP_DIRNAME = "app-map"
CONFIG_NAME = "app-map.config.yaml"


@dataclass
class Config:
    map_dir: Path                       # the app-map/ directory
    project_root: Path                  # its parent (where source lives)
    launch_surface: str | None = None
    source_globs: list[str] = field(default_factory=lambda: ["**/*"])
    screenshot_dirs: list[str] = field(default_factory=list)
    ignore: list[str] = field(default_factory=list)
    raw: dict[str, Any] = field(default_factory=dict)

    @property
    def surfaces_dir(self) -> Path:
        return self.map_dir / "surfaces"

    @property
    def schema_path(self) -> Path:
        return self.map_dir / "schema" / "surface.schema.json"

    @property
    def rendered_dir(self) -> Path:
        return self.map_dir / "rendered"

    @property
    def manifest_path(self) -> Path:
        return self.map_dir / "manifest.yaml"


def find_map_dir(start: Path | None = None) -> Path | None:
    """Find the nearest `app-map/` directory, searching CWD, then the CWD
    itself if it *is* app-map/, then walking up parents."""
    start = (start or Path.cwd()).resolve()
    candidates = [start / MAP_DIRNAME, start]
    for cand in candidates:
        if (cand / CONFIG_NAME).is_file() or (cand.name == MAP_DIRNAME and cand.is_dir()):
            return cand
    for parent in start.parents:
        cand = parent / MAP_DIRNAME
        if (cand / CONFIG_NAME).is_file():
            return cand
    return None


def load_config(map_dir: Path) -> Config:
    cfg_path = map_dir / CONFIG_NAME
    raw: dict[str, Any] = {}
    if cfg_path.is_file():
        raw = yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
    return Config(
        map_dir=map_dir,
        project_root=map_dir.parent,
        launch_surface=raw.get("launch_surface"),
        source_globs=list(raw.get("source_globs") or ["**/*"]),
        screenshot_dirs=list(raw.get("screenshot_dirs") or []),
        ignore=list(raw.get("ignore") or []),
        raw=raw,
    )
