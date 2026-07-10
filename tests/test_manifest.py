"""§5 The front-door index (manifest) — appmap/manifest.py."""

from __future__ import annotations

import unittest

from appmap.links import build_links
from appmap.manifest import build_manifest
from appmap.model import load_surfaces

from tests._fixtures import TempMap


def _build(tm: TempMap):
    cfg = tm.config()
    surfaces = load_surfaces(cfg.surfaces_dir)
    links = build_links(surfaces)
    return build_manifest(surfaces, links, cfg), surfaces, links, cfg


class ManifestIndexTests(unittest.TestCase):
    def test_index_fields_and_id_ordering(self) -> None:
        with TempMap() as tm:
            tm.write_surface(
                "b-dir",
                {
                    "id": "b-id",
                    "title": "B",
                    "kind": "screen",
                    "last_verified": {"sha": "deadbee", "date": "2026-01-01"},
                },
            )
            tm.write_surface("a-dir", {"id": "a-id", "title": "A", "kind": "screen"})
            manifest, *_ = _build(tm)

            self.assertEqual(list(manifest["surfaces"].keys()), ["a-id", "b-id"])
            entry = manifest["surfaces"]["b-id"]
            self.assertEqual(entry["title"], "B")
            self.assertEqual(entry["kind"], "screen")
            self.assertEqual(entry["path"], "surfaces/b-id/surface.md")
            self.assertEqual(entry["last_verified"], "deadbee")
            self.assertFalse(entry["needs_review"])

            self.assertIsNone(manifest["surfaces"]["a-id"]["last_verified"])

    def test_review_queue_from_needs_review(self) -> None:
        with TempMap() as tm:
            tm.write_surface(
                "flagged", {"id": "flagged", "title": "F", "kind": "screen", "needs_review": True}
            )
            tm.write_surface("clean", {"id": "clean", "title": "C", "kind": "screen"})
            manifest, *_ = _build(tm)
            self.assertEqual(manifest["review_queue"], ["flagged"])

    def test_dangling_links_mapping(self) -> None:
        with TempMap() as tm:
            tm.write_surface(
                "home",
                {
                    "id": "home",
                    "title": "Home",
                    "kind": "screen",
                    "edges": [{"id": "e1", "to": "ghost"}],
                },
            )
            manifest, *_ = _build(tm)
            self.assertEqual(
                manifest["link_health"]["dangling_links"],
                [{"from": "home", "to": "ghost", "kind": "edge", "ref": "e1"}],
            )

    def test_launch_surface_passthrough(self) -> None:
        with TempMap() as tm:
            tm.write_config(launch_surface="home")
            manifest, *_ = _build(tm)
            self.assertEqual(manifest["launch_surface"], "home")

    def test_no_volatile_fields(self) -> None:
        """Locks in the churn fix: the manifest carries no wall-clock
        timestamp or git sha, so committing it produces no diff noise."""
        with TempMap() as tm:
            tm.write_surface("home", {"id": "home", "title": "Home", "kind": "screen"})
            manifest, *_ = _build(tm)
            self.assertNotIn("generated_at", manifest)
            self.assertNotIn("map_sha", manifest)


if __name__ == "__main__":
    unittest.main()
