// Safe record handling — SurfaceRecord parse semantics. The body is tier-3
// prose and must survive parsing byte-for-byte.

import XCTest

@testable import AppMapKit

final class BodyPreservationTests: XCTestCase {
    func testBodyPreservedVerbatim() throws {
        let body = "## Notes\n\nSome text.\n\n---\n\nMore after the divider.\n"
        let tm = try TempMap()
        let path = try tm.writeSurfaceRaw("foo", "---\nid: foo\ntitle: Foo\nkind: screen\n---\n" + body)
        let surface = try parseSurface(at: path)
        XCTAssertEqual(surface.body, body)
    }

    func testDashesInsideBodySurvive() throws {
        let body = "Before\n\n---\n\nAfter\n"
        let tm = try TempMap()
        let path = try tm.writeSurfaceRaw("foo", "---\nid: foo\ntitle: Foo\nkind: screen\n---\n" + body)
        let surface = try parseSurface(at: path)
        XCTAssertTrue(surface.body.contains("---"))
        XCTAssertEqual(surface.body, body)
    }

    func testTrailingNewlinesPreserved() throws {
        let body = "Some prose.\n\n\n"
        let tm = try TempMap()
        let path = try tm.writeSurfaceRaw("foo", "---\nid: foo\ntitle: Foo\nkind: screen\n---\n" + body)
        let surface = try parseSurface(at: path)
        XCTAssertEqual(surface.body, body)
    }

    func testRawFrontmatterPreservedVerbatim() throws {
        let fm = "id: foo\ntitle: Foo\nkind: screen\nstates:\n  - { name: default, note: \"flow style\" }\n"
        let tm = try TempMap()
        let path = try tm.writeSurfaceRaw("foo", "---\n\(fm)---\nBody.\n")
        let surface = try parseSurface(at: path)
        XCTAssertEqual(surface.rawFrontmatter, "\n" + fm)
        XCTAssertTrue(surface.hasFrontmatter)
    }
}

final class NoFrontmatterTests: XCTestCase {
    func testFileWithNoFrontmatterIsTolerated() throws {
        let text = "Just a plain markdown file, no frontmatter here.\n"
        let tm = try TempMap()
        let path = try tm.writeSurfaceRaw("plain", text)
        let surface = try parseSurface(at: path)
        XCTAssertTrue(surface.data.isEmpty)
        XCTAssertEqual(surface.body, text)
        XCTAssertFalse(surface.hasFrontmatter)
        // defaults still work off the empty data dict
        XCTAssertEqual(surface.id, "plain")
        XCTAssertEqual(surface.kind, "screen")
    }
}

final class LoadSurfacesOrderingTests: XCTestCase {
    func testLoadSurfacesSortedByIDNotDirname() throws {
        let tm = try TempMap()
        try tm.writeSurface("zeta-dir", ["id": "b-id", "title": "B", "kind": "screen"])
        try tm.writeSurface("alpha-dir", ["id": "c-id", "title": "C", "kind": "screen"])
        try tm.writeSurface("mid-dir", ["id": "a-id", "title": "A", "kind": "screen"])
        let surfaces = loadSurfaces(in: tm.config().surfacesDir)
        XCTAssertEqual(surfaces.map(\.id), ["a-id", "b-id", "c-id"])
    }

    func testLoadSurfacesEmptyDir() throws {
        let tm = try TempMap()
        XCTAssertTrue(loadSurfaces(in: tm.config().surfacesDir).isEmpty)
    }

    func testLoadSurfacesMissingDir() throws {
        let tm = try TempMap()
        let missing = tm.mapDir.appendingPathComponent("surfaces/does-not-exist")
        XCTAssertTrue(loadSurfaces(in: missing).isEmpty)
    }
}

final class PropertyDefaultsTests: XCTestCase {
    func testDefaultsWhenFieldsAbsent() throws {
        let tm = try TempMap()
        let path = try tm.writeSurfaceRaw("bare", "---\n{}\n---\n")
        let surface = try parseSurface(at: path)
        XCTAssertEqual(surface.id, "bare")  // falls back to dir name
        XCTAssertEqual(surface.title, "bare")  // falls back to id
        XCTAssertEqual(surface.kind, "screen")
        XCTAssertTrue(surface.contains.isEmpty)
        XCTAssertTrue(surface.edges.isEmpty)
        XCTAssertTrue(surface.entryPoints.isEmpty)
        XCTAssertTrue(surface.states.isEmpty)
        XCTAssertTrue(surface.codeAnchor.isEmpty)
        XCTAssertFalse(surface.needsReview)
        XCTAssertTrue(surface.lastVerified.isEmpty)
    }

    func testExplicitFieldsOverrideDefaults() throws {
        let tm = try TempMap()
        let path = try tm.writeSurface("home", [
            "id": "home",
            "title": "Home Screen",
            "kind": "tab-root",
            "needs_review": true,
            "last_verified": ["sha": "abc123", "date": "2026-01-01"],
        ])
        let surface = try parseSurface(at: path)
        XCTAssertEqual(surface.title, "Home Screen")
        XCTAssertEqual(surface.kind, "tab-root")
        XCTAssertTrue(surface.needsReview)
        XCTAssertEqual(surface.lastVerified["sha"] as? String, "abc123")
        XCTAssertEqual(surface.lastVerified["date"] as? String, "2026-01-01")
    }
}
