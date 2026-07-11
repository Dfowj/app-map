"""§8 Finding and bootstrapping a map — appmap/config.py."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from appmap.config import CONFIG_NAME, find_map_dir, load_config


class FindMapDirTests(unittest.TestCase):
    def test_finds_app_map_subdir_of_cwd(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            # resolve() up front: find_map_dir resolves its start path
            # internally (following macOS's /var -> /private/var symlink).
            project = Path(td).resolve()
            (project / "app-map").mkdir()
            found = find_map_dir(project)
            self.assertEqual(found, project / "app-map")

    def test_finds_cwd_when_cwd_is_app_map(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            map_dir = Path(td).resolve() / "app-map"
            map_dir.mkdir()
            found = find_map_dir(map_dir)
            self.assertEqual(found, map_dir)

    def test_walks_up_parents_for_config(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            project = Path(td).resolve()
            map_dir = project / "app-map"
            map_dir.mkdir()
            (map_dir / CONFIG_NAME).write_text("launch_surface: null\n", encoding="utf-8")
            deep = project / "sub" / "dir"
            deep.mkdir(parents=True)
            found = find_map_dir(deep)
            self.assertEqual(found, map_dir)

    def test_returns_none_when_not_found(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            isolated = Path(td) / "no-map-anywhere"
            isolated.mkdir()
            found = find_map_dir(isolated)
            self.assertIsNone(found)


class LoadConfigTests(unittest.TestCase):
    def test_defaults_when_no_config_file(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            map_dir = Path(td) / "app-map"
            map_dir.mkdir()
            cfg = load_config(map_dir)
            self.assertIsNone(cfg.launch_surface)
            self.assertEqual(cfg.source_globs, ["**/*"])
            self.assertEqual(cfg.screenshot_dirs, [])
            self.assertEqual(cfg.ignore, [])
            self.assertEqual(cfg.project_root, map_dir.parent)

    def test_defaults_when_keys_absent_from_partial_config(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            map_dir = Path(td) / "app-map"
            map_dir.mkdir()
            (map_dir / CONFIG_NAME).write_text("launch_surface: home\n", encoding="utf-8")
            cfg = load_config(map_dir)
            self.assertEqual(cfg.launch_surface, "home")
            self.assertEqual(cfg.source_globs, ["**/*"])
            self.assertEqual(cfg.screenshot_dirs, [])
            self.assertEqual(cfg.ignore, [])

    def test_explicit_values_are_read(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            map_dir = Path(td) / "app-map"
            map_dir.mkdir()
            (map_dir / CONFIG_NAME).write_text(
                "launch_surface: tab-bar\n"
                "source_globs: ['Sources/**/*.swift']\n"
                "screenshot_dirs: ['Snapshots']\n"
                "ignore: ['Sources/Generated/**']\n",
                encoding="utf-8",
            )
            cfg = load_config(map_dir)
            self.assertEqual(cfg.launch_surface, "tab-bar")
            self.assertEqual(cfg.source_globs, ["Sources/**/*.swift"])
            self.assertEqual(cfg.screenshot_dirs, ["Snapshots"])
            self.assertEqual(cfg.ignore, ["Sources/Generated/**"])


if __name__ == "__main__":
    unittest.main()
