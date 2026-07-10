"""Hermetic temp app-map/ tree builder shared by the test modules.

Each test gets its own tempfile.TemporaryDirectory so records/config/schema
never collide between tests and the real samples/shopmini tree is never
touched.
"""

from __future__ import annotations

import shutil
import tempfile
from pathlib import Path
from typing import Any

import yaml

from appmap.config import CONFIG_NAME, Config, load_config
from appmap.model import Surface, parse_surface

_APPMAP_PKG = Path(__file__).resolve().parent.parent / "appmap"


class TempMap:
    """A temp project root containing an `app-map/` dir.

    Usage:
        with TempMap() as tm:
            tm.write_config(launch_surface="home")
            tm.write_surface("home", {"id": "home", "title": "Home", "kind": "screen"})
            cfg = tm.config()
            ...
    """

    def __init__(self) -> None:
        self._tmpdir = tempfile.TemporaryDirectory()
        self.project_root = Path(self._tmpdir.name)
        self.map_dir = self.project_root / "app-map"
        (self.map_dir / "surfaces").mkdir(parents=True)
        (self.map_dir / "schema").mkdir(parents=True)
        shutil.copyfile(
            _APPMAP_PKG / "schema" / "surface.schema.json",
            self.map_dir / "schema" / "surface.schema.json",
        )

    # ── config ────────────────────────────────────────────────────────────
    def write_config(self, **fields: Any) -> None:
        """Write app-map.config.yaml with the given keys (any omitted key is
        simply absent, exercising load_config's defaults)."""
        (self.map_dir / CONFIG_NAME).write_text(
            yaml.safe_dump(fields, sort_keys=False), encoding="utf-8"
        )

    def config(self) -> Config:
        return load_config(self.map_dir)

    # ── surfaces ──────────────────────────────────────────────────────────
    def write_surface(self, surface_id: str, frontmatter: dict[str, Any], body: str = "") -> Path:
        """Write surfaces/<id>/surface.md with the given frontmatter dict + body."""
        surface_dir = self.map_dir / "surfaces" / surface_id
        surface_dir.mkdir(parents=True, exist_ok=True)
        head = yaml.safe_dump(frontmatter, sort_keys=False, allow_unicode=True).rstrip("\n")
        path = surface_dir / "surface.md"
        path.write_text(f"---\n{head}\n---\n{body}", encoding="utf-8")
        return path

    def write_surface_raw(self, surface_id: str, text: str) -> Path:
        """Write surfaces/<id>/surface.md with literal text, untouched."""
        surface_dir = self.map_dir / "surfaces" / surface_id
        surface_dir.mkdir(parents=True, exist_ok=True)
        path = surface_dir / "surface.md"
        path.write_text(text, encoding="utf-8")
        return path

    def load_surface(self, surface_id: str) -> Surface:
        return parse_surface(self.map_dir / "surfaces" / surface_id / "surface.md")

    # ── arbitrary project files (code_anchor / screenshot targets) ─────────
    def write_file(self, rel_path: str, content: str = "") -> Path:
        path = self.project_root / rel_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return path

    # ── lifecycle ────────────────────────────────────────────────────────
    def close(self) -> None:
        self._tmpdir.cleanup()

    def __enter__(self) -> "TempMap":
        return self

    def __exit__(self, *exc: Any) -> None:
        self.close()
