// Manifest derivation — id-sorted, no volatile fields, byte-identical on
// re-render. Ported from tests/test_manifest.py semantics.

import XCTest
import Yams

@testable import AppMapKit

final class ManifestTests: XCTestCase {
    private func makeMap() throws -> TempMap {
        let tm = try TempMap()
        try tm.writeConfig(["launch_surface": "home"])
        try tm.writeSurface("home", [
            "id": "home", "title": "Home", "kind": "tab-root",
            "edges": [["id": "to-cart", "to": "cart"], ["id": "to-ghost", "to": "ghost"]],
        ])
        try tm.writeSurface("cart", [
            "id": "cart", "title": "Cart", "kind": "screen",
            "needs_review": true,
            "last_verified": ["sha": "abc123", "date": "2026-01-01"],
        ])
        return tm
    }

    private func manifest(_ tm: TempMap) -> String {
        let cfg = tm.config()
        let surfaces = loadSurfaces(in: cfg.surfacesDir)
        return buildManifestYAML(surfaces: surfaces, links: buildLinks(surfaces), cfg: cfg)
    }

    func testManifestContent() throws {
        let tm = try makeMap()
        let text = manifest(tm)
        let loaded = try XCTUnwrap(asStringDict(try Yams.load(yaml: text)))

        XCTAssertEqual(loaded["launch_surface"] as? String, "home")
        let index = try XCTUnwrap(asStringDict(loaded["surfaces"]))
        XCTAssertEqual(Set(index.keys), ["home", "cart"])
        let cart = try XCTUnwrap(asStringDict(index["cart"]))
        XCTAssertEqual(cart["title"] as? String, "Cart")
        XCTAssertEqual(cart["kind"] as? String, "screen")
        XCTAssertEqual(cart["path"] as? String, "surfaces/cart/surface.md")
        XCTAssertEqual(cart["last_verified"] as? String, "abc123")
        XCTAssertEqual(cart["needs_review"] as? Bool, true)
        let home = try XCTUnwrap(asStringDict(index["home"]))
        XCTAssertTrue(home["last_verified"] is NSNull || home["last_verified"] == nil)

        XCTAssertEqual((loaded["review_queue"] as? [Any])?.compactMap { $0 as? String }, ["cart"])
        let health = try XCTUnwrap(asStringDict(loaded["link_health"]))
        let dangling = (health["dangling_links"] as? [Any])?.compactMap { asStringDict($0) } ?? []
        XCTAssertEqual(dangling.count, 1)
        XCTAssertEqual(dangling.first?["from"] as? String, "home")
        XCTAssertEqual(dangling.first?["to"] as? String, "ghost")
        XCTAssertEqual(dangling.first?["kind"] as? String, "edge")
    }

    func testManifestIsIDSorted() throws {
        let tm = try makeMap()
        let text = manifest(tm)
        let cartPos = try XCTUnwrap(text.range(of: "  cart:")).lowerBound
        let homePos = try XCTUnwrap(text.range(of: "  home:")).lowerBound
        XCTAssertLessThan(cartPos, homePos)
    }

    func testRerenderIsByteIdentical() throws {
        let tm = try makeMap()
        XCTAssertEqual(manifest(tm), manifest(tm))
    }

    func testEmptyMapManifest() throws {
        let tm = try TempMap()
        let text = manifest(tm)
        XCTAssertTrue(text.contains("surfaces: {}"))
        XCTAssertTrue(text.contains("review_queue: []"))
        XCTAssertTrue(text.contains("dangling_links: []"))
        XCTAssertNoThrow(try Yams.load(yaml: text))
    }

    func testScalarQuoting() {
        XCTAssertEqual(yamlScalar("Cart"), "Cart")
        XCTAssertEqual(yamlScalar(nil), "null")
        XCTAssertEqual(yamlScalar("true"), "'true'")
        XCTAssertEqual(yamlScalar("it's"), "'it''s'")
        XCTAssertEqual(yamlScalar("a: b"), "'a: b'")
        XCTAssertEqual(yamlScalar(""), "''")
    }
}
