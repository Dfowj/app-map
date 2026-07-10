"""§6 Warning on drift and broken things (validate) — appmap/validate.py."""

from __future__ import annotations

import unittest

from appmap.model import load_surfaces
from appmap.validate import ERROR, WARN, validate

from tests._fixtures import TempMap


def _validate(tm: TempMap):
    cfg = tm.config()
    surfaces = load_surfaces(cfg.surfaces_dir)
    return validate(surfaces, cfg)


class SchemaFindingsTests(unittest.TestCase):
    def test_bad_enum_is_warn(self) -> None:
        with TempMap() as tm:
            tm.write_surface("home", {"id": "home", "title": "Home", "kind": "not-a-kind"})
            findings = _validate(tm)
            self.assertTrue(
                any(f.level == WARN and "not one of" in f.message for f in findings)
            )

    def test_missing_required_is_warn(self) -> None:
        with TempMap() as tm:
            tm.write_surface("home", {"id": "home", "kind": "screen"})  # no title
            findings = _validate(tm)
            self.assertTrue(
                any(f.level == WARN and "missing required 'title'" in f.message for f in findings)
            )

    def test_wrong_type_is_warn(self) -> None:
        with TempMap() as tm:
            tm.write_surface(
                "home",
                {"id": "home", "title": "Home", "kind": "screen", "contains": "not-a-list"},
            )
            findings = _validate(tm)
            self.assertTrue(
                any(f.level == WARN and "expected array" in f.message for f in findings)
            )


class AnchorFindingsTests(unittest.TestCase):
    def test_missing_anchor_file_is_error(self) -> None:
        with TempMap() as tm:
            tm.write_surface(
                "home",
                {
                    "id": "home",
                    "title": "Home",
                    "kind": "screen",
                    "code_anchor": {"file": "Sources/DoesNotExist.swift"},
                },
            )
            findings = _validate(tm)
            self.assertTrue(
                any(
                    f.level == ERROR and "code_anchor.file missing" in f.message
                    for f in findings
                )
            )

    def test_missing_symbol_is_warn(self) -> None:
        with TempMap() as tm:
            tm.write_file("Sources/Foo.swift", "struct Foo {}\n")
            tm.write_surface(
                "home",
                {
                    "id": "home",
                    "title": "Home",
                    "kind": "screen",
                    "code_anchor": {"file": "Sources/Foo.swift", "symbol": "Bar"},
                },
            )
            findings = _validate(tm)
            self.assertTrue(
                any(
                    f.level == WARN and "symbol 'Bar' not found" in f.message
                    for f in findings
                )
            )

    def test_anchor_file_and_symbol_present_no_finding(self) -> None:
        with TempMap() as tm:
            tm.write_file("Sources/Foo.swift", "struct Foo {}\n")
            tm.write_surface(
                "home",
                {
                    "id": "home",
                    "title": "Home",
                    "kind": "screen",
                    "code_anchor": {"file": "Sources/Foo.swift", "symbol": "Foo"},
                },
            )
            findings = _validate(tm)
            self.assertFalse(any("code_anchor" in f.message for f in findings))


class ScreenshotFindingsTests(unittest.TestCase):
    def test_unresolved_screenshot_is_warn(self) -> None:
        with TempMap() as tm:
            tm.write_surface(
                "home",
                {
                    "id": "home",
                    "title": "Home",
                    "kind": "screen",
                    "states": [{"name": "default", "screenshot": "shot.png"}],
                },
            )
            findings = _validate(tm)
            self.assertTrue(
                any(f.level == WARN and "screenshot unresolved" in f.message for f in findings)
            )

    def test_resolved_screenshot_no_finding(self) -> None:
        with TempMap() as tm:
            tm.write_surface(
                "home",
                {
                    "id": "home",
                    "title": "Home",
                    "kind": "screen",
                    "states": [{"name": "default", "screenshot": "shot.png"}],
                },
            )
            tm.write_file("app-map/surfaces/home/shot.png", "fake-png-bytes")
            findings = _validate(tm)
            self.assertFalse(any("screenshot unresolved" in f.message for f in findings))


class DanglingFindingsTests(unittest.TestCase):
    def test_dangling_link_is_error(self) -> None:
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
            findings = _validate(tm)
            self.assertTrue(
                any(
                    f.level == ERROR and "dangling edge -> 'ghost'" in f.message
                    for f in findings
                )
            )


class NeverBlocksTests(unittest.TestCase):
    def test_validate_never_raises_on_a_thoroughly_broken_map(self) -> None:
        with TempMap() as tm:
            tm.write_surface(
                "home",
                {
                    "id": "home",
                    "title": "Home",
                    "kind": "not-a-real-kind",
                    "code_anchor": {"file": "Sources/Missing.swift"},
                    "edges": [{"id": "e1", "to": "ghost"}],
                    "contains": "not-a-list",
                    "states": [{"name": "default", "screenshot": "missing.png"}],
                },
            )
            try:
                findings = _validate(tm)
            except Exception as e:  # pragma: no cover - the assertion below is the real check
                self.fail(f"validate() raised {e!r} on a broken map")
            self.assertGreater(len(findings), 0)


if __name__ == "__main__":
    unittest.main()
