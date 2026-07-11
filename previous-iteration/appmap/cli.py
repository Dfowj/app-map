"""Command-line interface: init | render | validate.

warn, record, never block — all subcommands return 0 unless the CLI itself is
misused (bad args / no map found).
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

from . import __version__
from .config import CONFIG_NAME, MAP_DIRNAME, find_map_dir, load_config
from .links import build_links
from .manifest import build_manifest, write_manifest
from .model import load_surfaces
from .render import render_map
from .validate import ERROR, validate

_TOOL_ROOT = Path(__file__).resolve().parent


def _resolve_config(explicit: str | None):
    if explicit:
        map_dir = Path(explicit).resolve()
    else:
        found = find_map_dir()
        if not found:
            print(
                f"error: no '{MAP_DIRNAME}/' found here or above. Run `app-map init` first,\n"
                f"       or pass --map <dir>.",
                file=sys.stderr,
            )
            return None
        map_dir = found
    if not map_dir.is_dir():
        print(f"error: map dir does not exist: {map_dir}", file=sys.stderr)
        return None
    return load_config(map_dir)


# ── init ─────────────────────────────────────────────────────────────────────

def cmd_init(args) -> int:
    project_root = Path(args.dir or ".").resolve()
    map_dir = project_root / MAP_DIRNAME
    (map_dir / "surfaces").mkdir(parents=True, exist_ok=True)
    (map_dir / "schema").mkdir(parents=True, exist_ok=True)

    # schema (canonical copy from the tool)
    schema_src = _TOOL_ROOT / "schema" / "surface.schema.json"
    schema_dst = map_dir / "schema" / "surface.schema.json"
    shutil.copyfile(schema_src, schema_dst)

    # config (don't clobber an existing one)
    cfg_dst = map_dir / CONFIG_NAME
    if not cfg_dst.exists():
        shutil.copyfile(_TOOL_ROOT / "templates" / "app-map.config.yaml", cfg_dst)

    print(f"initialized app map at {map_dir}")
    print("  next: set launch_surface in app-map.config.yaml and add surfaces/<id>/surface.md")
    print(f"  scaffold a surface from {_TOOL_ROOT / 'templates' / 'surface.md'}")
    return 0


# ── validate ─────────────────────────────────────────────────────────────────

def cmd_validate(args) -> int:
    cfg = _resolve_config(args.map)
    if cfg is None:
        return 2
    surfaces = load_surfaces(cfg.surfaces_dir)
    findings = validate(surfaces, cfg)
    if not findings:
        print(f"ok: {len(surfaces)} surface(s), no findings.")
        return 0
    errors = sum(1 for f in findings if f.level == ERROR)
    warns = len(findings) - errors
    for f in findings:
        print(f"  [{f.level:5}] {f.surface}: {f.message}")
    print(f"\n{len(surfaces)} surface(s): {errors} error-level, {warns} warn-level finding(s).")
    print("(warn, record, never block — exit 0)")
    return 0


# ── render ───────────────────────────────────────────────────────────────────

def cmd_render(args) -> int:
    cfg = _resolve_config(args.map)
    if cfg is None:
        return 2
    surfaces = load_surfaces(cfg.surfaces_dir)
    links = build_links(surfaces)

    manifest = build_manifest(surfaces, links, cfg)
    write_manifest(manifest, cfg)

    out_dir = render_map(surfaces, links, cfg)

    dangling = manifest["link_health"]["dangling_links"]
    review = manifest["review_queue"]
    print(f"rendered {len(surfaces)} surface(s) -> {out_dir}")
    print(f"manifest -> {cfg.manifest_path}")
    if review:
        print(f"  review queue: {', '.join(review)}")
    if dangling:
        for d in dangling:
            print(f"  broken link: {d['from']} -> {d['to']} ({d['kind']})")
    return 0


# ── parser ───────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="app-map", description="App Map — map-as-projection tooling.")
    p.add_argument("--version", action="version", version=f"app-map {__version__}")
    sub = p.add_subparsers(dest="cmd", required=True)

    pi = sub.add_parser("init", help="scaffold app-map/ into a project")
    pi.add_argument("dir", nargs="?", help="project root (default: cwd)")
    pi.set_defaults(func=cmd_init)

    pv = sub.add_parser("validate", help="report drift / broken links / bad anchors (never fails)")
    pv.add_argument("--map", help="path to app-map/ dir (default: auto-detect)")
    pv.set_defaults(func=cmd_validate)

    pr = sub.add_parser("render", help="rebuild manifest.yaml + rendered/ (wholesale)")
    pr.add_argument("--map", help="path to app-map/ dir (default: auto-detect)")
    pr.set_defaults(func=cmd_render)

    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)
