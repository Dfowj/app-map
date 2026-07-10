"""§4 Understanding how surfaces connect — appmap/links.py."""

from __future__ import annotations

import unittest

from appmap.links import build_links
from appmap.model import load_surfaces

from tests._fixtures import TempMap


class IncomingInversionTests(unittest.TestCase):
    def test_outgoing_edge_becomes_incoming_backlink(self) -> None:
        with TempMap() as tm:
            tm.write_surface(
                "home",
                {
                    "id": "home",
                    "title": "Home",
                    "kind": "screen",
                    "edges": [{"id": "to-cart", "to": "cart", "trigger": "Tap cart"}],
                },
            )
            tm.write_surface("cart", {"id": "cart", "title": "Cart", "kind": "screen"})
            cfg = tm.config()
            surfaces = load_surfaces(cfg.surfaces_dir)
            links = build_links(surfaces)

            self.assertEqual(len(links.incoming["cart"]), 1)
            inc = links.incoming["cart"][0]
            self.assertEqual(inc.from_id, "home")
            self.assertEqual(inc.edge["id"], "to-cart")
            self.assertEqual(links.incoming["home"], [])


class DanglingLinkTests(unittest.TestCase):
    def test_dangling_edge(self) -> None:
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
            cfg = tm.config()
            links = build_links(load_surfaces(cfg.surfaces_dir))
            self.assertEqual(len(links.dangling), 1)
            d = links.dangling[0]
            self.assertEqual(d.from_id, "home")
            self.assertEqual(d.to, "ghost")
            self.assertEqual(d.kind, "edge")
            self.assertEqual(d.ref, "e1")

    def test_dangling_contains(self) -> None:
        with TempMap() as tm:
            tm.write_surface(
                "tab-bar",
                {
                    "id": "tab-bar",
                    "title": "Tabs",
                    "kind": "tab-bar",
                    "contains": ["ghost-tab"],
                },
            )
            cfg = tm.config()
            links = build_links(load_surfaces(cfg.surfaces_dir))
            self.assertEqual(len(links.dangling), 1)
            d = links.dangling[0]
            self.assertEqual(d.kind, "contains")
            self.assertEqual(d.to, "ghost-tab")
            self.assertEqual(d.ref, "ghost-tab")

    def test_dangling_entry_point(self) -> None:
        with TempMap() as tm:
            tm.write_surface(
                "home",
                {
                    "id": "home",
                    "title": "Home",
                    "kind": "screen",
                    "entry_points": [
                        {"type": "deepLink", "value": "app://ghost", "to": "ghost"}
                    ],
                },
            )
            cfg = tm.config()
            links = build_links(load_surfaces(cfg.surfaces_dir))
            self.assertEqual(len(links.dangling), 1)
            d = links.dangling[0]
            self.assertEqual(d.kind, "entry_point")
            self.assertEqual(d.to, "ghost")
            self.assertEqual(d.ref, "deepLink:app://ghost")

    def test_edge_missing_to_is_skipped_not_flagged(self) -> None:
        with TempMap() as tm:
            tm.write_surface(
                "home",
                {
                    "id": "home",
                    "title": "Home",
                    "kind": "screen",
                    "edges": [{"id": "no-target"}],
                },
            )
            cfg = tm.config()
            links = build_links(load_surfaces(cfg.surfaces_dir))
            self.assertEqual(links.dangling, [])
            self.assertEqual(links.incoming["home"], [])

    def test_clean_graph_has_no_dangling_links(self) -> None:
        with TempMap() as tm:
            tm.write_surface(
                "home",
                {
                    "id": "home",
                    "title": "Home",
                    "kind": "screen",
                    "edges": [{"id": "to-cart", "to": "cart"}],
                    "contains": ["cart"],
                    "entry_points": [{"type": "deepLink", "value": "app://cart", "to": "cart"}],
                },
            )
            tm.write_surface("cart", {"id": "cart", "title": "Cart", "kind": "screen"})
            cfg = tm.config()
            links = build_links(load_surfaces(cfg.surfaces_dir))
            self.assertEqual(links.dangling, [])


if __name__ == "__main__":
    unittest.main()
