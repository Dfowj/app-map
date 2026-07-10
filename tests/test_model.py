"""§3 Safe record handling — appmap/model.py."""

from __future__ import annotations

import unittest

from appmap.model import load_surfaces, parse_surface

from tests._fixtures import TempMap


class BodyRoundTripTests(unittest.TestCase):
    def test_body_round_trips_verbatim(self) -> None:
        body = "## Notes\n\nSome text.\n\n---\n\nMore after the divider.\n"
        text = "---\nid: foo\ntitle: Foo\nkind: screen\n---\n" + body
        with TempMap() as tm:
            path = tm.write_surface_raw("foo", text)
            surface = parse_surface(path)
            self.assertEqual(surface.body, body)

            # dump -> reparse -> body still identical (round-trip stability)
            path.write_text(surface.dumps(), encoding="utf-8")
            reparsed = parse_surface(path)
            self.assertEqual(reparsed.body, body)

    def test_dashes_inside_body_survive(self) -> None:
        body = "Before\n\n---\n\nAfter\n"
        text = "---\nid: foo\ntitle: Foo\nkind: screen\n---\n" + body
        with TempMap() as tm:
            path = tm.write_surface_raw("foo", text)
            surface = parse_surface(path)
            self.assertIn("---", surface.body)
            self.assertEqual(surface.body, body)

    def test_trailing_newlines_preserved(self) -> None:
        body = "Some prose.\n\n\n"
        text = "---\nid: foo\ntitle: Foo\nkind: screen\n---\n" + body
        with TempMap() as tm:
            path = tm.write_surface_raw("foo", text)
            surface = parse_surface(path)
            self.assertEqual(surface.body, body)


class NoFrontmatterTests(unittest.TestCase):
    def test_file_with_no_frontmatter_is_tolerated(self) -> None:
        text = "Just a plain markdown file, no frontmatter here.\n"
        with TempMap() as tm:
            path = tm.write_surface_raw("plain", text)
            surface = parse_surface(path)
            self.assertEqual(surface.data, {})
            self.assertEqual(surface.body, text)
            # defaults still work off the empty data dict
            self.assertEqual(surface.id, "plain")
            self.assertEqual(surface.kind, "screen")


class LoadSurfacesOrderingTests(unittest.TestCase):
    def test_load_surfaces_sorted_by_id_not_dirname(self) -> None:
        with TempMap() as tm:
            # dir names deliberately out of order relative to the id field
            tm.write_surface("zeta-dir", {"id": "b-id", "title": "B", "kind": "screen"})
            tm.write_surface("alpha-dir", {"id": "c-id", "title": "C", "kind": "screen"})
            tm.write_surface("mid-dir", {"id": "a-id", "title": "A", "kind": "screen"})
            cfg = tm.config()
            surfaces = load_surfaces(cfg.surfaces_dir)
            self.assertEqual([s.id for s in surfaces], ["a-id", "b-id", "c-id"])

    def test_load_surfaces_empty_dir(self) -> None:
        with TempMap() as tm:
            cfg = tm.config()
            self.assertEqual(load_surfaces(cfg.surfaces_dir), [])

    def test_load_surfaces_missing_dir(self) -> None:
        with TempMap() as tm:
            missing = tm.map_dir / "surfaces" / "does-not-exist"
            self.assertEqual(load_surfaces(missing), [])


class PropertyDefaultsTests(unittest.TestCase):
    def test_defaults_when_fields_absent(self) -> None:
        with TempMap() as tm:
            path = tm.write_surface("bare", {})
            surface = parse_surface(path)
            self.assertEqual(surface.id, "bare")  # falls back to dir name
            self.assertEqual(surface.title, "bare")  # falls back to id
            self.assertEqual(surface.kind, "screen")
            self.assertEqual(surface.contains, [])
            self.assertEqual(surface.edges, [])
            self.assertEqual(surface.entry_points, [])
            self.assertEqual(surface.states, [])
            self.assertEqual(surface.code_anchor, {})
            self.assertFalse(surface.needs_review)
            self.assertEqual(surface.last_verified, {})

    def test_explicit_fields_override_defaults(self) -> None:
        with TempMap() as tm:
            path = tm.write_surface(
                "home",
                {
                    "id": "home",
                    "title": "Home Screen",
                    "kind": "tab-root",
                    "needs_review": True,
                    "last_verified": {"sha": "abc123", "date": "2026-01-01"},
                },
            )
            surface = parse_surface(path)
            self.assertEqual(surface.title, "Home Screen")
            self.assertEqual(surface.kind, "tab-root")
            self.assertTrue(surface.needs_review)
            self.assertEqual(surface.last_verified, {"sha": "abc123", "date": "2026-01-01"})


if __name__ == "__main__":
    unittest.main()
