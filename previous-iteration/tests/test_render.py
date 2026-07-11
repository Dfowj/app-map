"""§7 The browsable rendered map — appmap/render.py (smoke tests)."""

from __future__ import annotations

import unittest

from appmap.links import build_links
from appmap.model import load_surfaces
from appmap.render import render_map

from tests._fixtures import TempMap


class RenderSmokeTests(unittest.TestCase):
    def test_index_and_per_surface_files_written(self) -> None:
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

            out_dir = render_map(surfaces, links, cfg)

            self.assertTrue((out_dir / "index.html").is_file())
            self.assertTrue((out_dir / "surface.home.html").is_file())
            self.assertTrue((out_dir / "surface.cart.html").is_file())

    def test_page_shows_outgoing_edges_and_backlinks(self) -> None:
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
            out_dir = render_map(surfaces, links, cfg)

            home_html = (out_dir / "surface.home.html").read_text(encoding="utf-8")
            self.assertIn("Navigates to", home_html)
            self.assertIn("surface.cart.html", home_html)

            cart_html = (out_dir / "surface.cart.html").read_text(encoding="utf-8")
            self.assertIn("Reached from", cart_html)
            self.assertIn("surface.home.html", cart_html)

    def test_body_prose_present(self) -> None:
        with TempMap() as tm:
            tm.write_surface(
                "home",
                {"id": "home", "title": "Home", "kind": "screen"},
                body="## Description\n\nA very particular piece of prose.\n",
            )
            cfg = tm.config()
            surfaces = load_surfaces(cfg.surfaces_dir)
            links = build_links(surfaces)
            out_dir = render_map(surfaces, links, cfg)

            home_html = (out_dir / "surface.home.html").read_text(encoding="utf-8")
            self.assertIn("A very particular piece of prose.", home_html)

    def test_broken_link_banner_on_index(self) -> None:
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
            surfaces = load_surfaces(cfg.surfaces_dir)
            links = build_links(surfaces)
            out_dir = render_map(surfaces, links, cfg)

            index_html = (out_dir / "index.html").read_text(encoding="utf-8")
            self.assertIn("Broken links:", index_html)
            self.assertIn("ghost", index_html)


if __name__ == "__main__":
    unittest.main()
