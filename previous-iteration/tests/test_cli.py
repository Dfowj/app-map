"""§8 Finding and bootstrapping a map — end-to-end CLI via appmap.cli.main."""

from __future__ import annotations

import contextlib
import io
import os
import tempfile
import unittest
from pathlib import Path

from appmap.cli import main

from tests._fixtures import TempMap


def _run(argv: list[str]) -> int:
    with contextlib.redirect_stdout(io.StringIO()):
        return main(argv)


class InitCommandTests(unittest.TestCase):
    def test_init_scaffolds_config_and_schema(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            project_root = Path(td)
            rc = _run(["init", str(project_root)])
            self.assertEqual(rc, 0)

            map_dir = project_root / "app-map"
            self.assertTrue((map_dir / "surfaces").is_dir())
            self.assertTrue((map_dir / "schema" / "surface.schema.json").is_file())
            self.assertTrue((map_dir / "app-map.config.yaml").is_file())

    def test_init_does_not_clobber_existing_config(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            project_root = Path(td)
            rc1 = _run(["init", str(project_root)])
            self.assertEqual(rc1, 0)
            cfg_path = project_root / "app-map" / "app-map.config.yaml"
            cfg_path.write_text("launch_surface: home\n", encoding="utf-8")

            rc2 = _run(["init", str(project_root)])
            self.assertEqual(rc2, 0)
            self.assertEqual(cfg_path.read_text(encoding="utf-8"), "launch_surface: home\n")


class NoMapFoundTests(unittest.TestCase):
    def test_validate_exits_2_when_no_map_found(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            isolated = Path(td) / "no-map-here"
            isolated.mkdir()
            orig_cwd = Path.cwd()
            os.chdir(isolated)
            try:
                rc = _run(["validate"])
            finally:
                os.chdir(orig_cwd)
            self.assertEqual(rc, 2)

    def test_render_exits_2_when_no_map_found(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            isolated = Path(td) / "no-map-here"
            isolated.mkdir()
            orig_cwd = Path.cwd()
            os.chdir(isolated)
            try:
                rc = _run(["render"])
            finally:
                os.chdir(orig_cwd)
            self.assertEqual(rc, 2)


class NeverBlockCliTests(unittest.TestCase):
    def test_broken_map_still_exits_0_from_validate_and_render(self) -> None:
        with TempMap() as tm:
            tm.write_surface(
                "home",
                {
                    "id": "home",
                    "title": "Home",
                    "kind": "screen",
                    "edges": [{"id": "e1", "to": "ghost"}],  # dangling
                    "code_anchor": {"file": "Sources/Deleted.swift"},  # never existed
                },
            )
            rc_validate = _run(["validate", "--map", str(tm.map_dir)])
            self.assertEqual(rc_validate, 0)

            rc_render = _run(["render", "--map", str(tm.map_dir)])
            self.assertEqual(rc_render, 0)


class RenderCommandTests(unittest.TestCase):
    def test_render_writes_manifest_and_rendered_dir(self) -> None:
        with TempMap() as tm:
            tm.write_surface("home", {"id": "home", "title": "Home", "kind": "screen"})
            rc = _run(["render", "--map", str(tm.map_dir)])
            self.assertEqual(rc, 0)
            self.assertTrue((tm.map_dir / "manifest.yaml").is_file())
            self.assertTrue((tm.map_dir / "rendered" / "index.html").is_file())


if __name__ == "__main__":
    unittest.main()
