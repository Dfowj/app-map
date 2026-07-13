// Static-site render — pages exist, link correctly, derive incoming links,
// and preserve/escape content. Ported from tests/test_render.py semantics.

import XCTest

@testable import AppMapKit

final class RenderTests: XCTestCase {
    private func makeMap() throws -> TempMap {
        let tm = try TempMap()
        try tm.writeConfig(["launch_surface": "home"])
        try tm.writeSurface(
            "home",
            [
                "id": "home", "title": "Home", "kind": "tab-root",
                "edges": [["id": "to-cart", "to": "cart", "trigger": "Tap cart icon"]],
            ],
            body: "\n## Description\n\nThe landing screen.\n")
        try tm.writeSurface(
            "cart",
            [
                "id": "cart", "title": "Cart", "kind": "screen",
                "states": [["name": "empty", "screenshot": "empty.png"]],
            ],
            body: "\n## Description\n\nShows <b>line items</b> & totals.\n")
        return tm
    }

    private func render(_ tm: TempMap) throws -> URL {
        let cfg = tm.config()
        let surfaces = loadSurfaces(in: cfg.surfacesDir)
        return try renderMap(surfaces, links: buildLinks(surfaces), cfg: cfg)
    }

    func testAllPagesEmitted() throws {
        let tm = try makeMap()
        let out = try render(tm)
        let fm = FileManager.default
        for name in ["index.html", "map.html", "surface.home.html", "surface.cart.html"] {
            XCTAssertTrue(
                fm.fileExists(atPath: out.appendingPathComponent(name).path), "missing \(name)")
        }
    }

    func testIncomingDerivedOnTargetPage() throws {
        let tm = try makeMap()
        let out = try render(tm)
        let cart = try String(
            contentsOf: out.appendingPathComponent("surface.cart.html"), encoding: .utf8)
        XCTAssertTrue(cart.contains("Reached from"))
        XCTAssertTrue(cart.contains("surface.home.html"))
        XCTAssertTrue(cart.contains("Tap cart icon"))
    }

    func testBodyHTMLIsEscaped() throws {
        let tm = try makeMap()
        let out = try render(tm)
        let cart = try String(
            contentsOf: out.appendingPathComponent("surface.cart.html"), encoding: .utf8)
        XCTAssertTrue(cart.contains("&lt;b&gt;line items&lt;/b&gt;"))
        XCTAssertFalse(cart.contains("<b>line items</b>"))
    }

    func testUnresolvedScreenshotMarked() throws {
        let tm = try makeMap()
        let out = try render(tm)
        let cart = try String(
            contentsOf: out.appendingPathComponent("surface.cart.html"), encoding: .utf8)
        XCTAssertTrue(cart.contains("unresolved"))
    }

    func testResolvedScreenshotGetsImgTag() throws {
        let tm = try makeMap()
        try tm.writeFile("app-map/surfaces/cart/empty.png", "fake")
        let out = try render(tm)
        let cart = try String(
            contentsOf: out.appendingPathComponent("surface.cart.html"), encoding: .utf8)
        XCTAssertTrue(cart.contains("src='../surfaces/cart/empty.png'"))
    }

    func testIndexListsSurfacesAndSnippets() throws {
        let tm = try makeMap()
        let out = try render(tm)
        let index = try String(
            contentsOf: out.appendingPathComponent("index.html"), encoding: .utf8)
        XCTAssertTrue(index.contains("surface.home.html"))
        XCTAssertTrue(index.contains("surface.cart.html"))
        XCTAssertTrue(index.contains("The landing screen."))
    }

    func testGraphNodesLinkToSurfacePages() throws {
        let tm = try makeMap()
        let out = try render(tm)
        let graph = try String(
            contentsOf: out.appendingPathComponent("map.html"), encoding: .utf8)
        XCTAssertTrue(graph.contains("href='surface.home.html'"))
        XCTAssertTrue(graph.contains("href='surface.cart.html'"))
        XCTAssertTrue(graph.contains("<svg"))
    }

    func testRenderIsDeterministic() throws {
        let tm = try makeMap()
        let out = try render(tm)
        let first = try String(
            contentsOf: out.appendingPathComponent("index.html"), encoding: .utf8)
        _ = try render(tm)
        let second = try String(
            contentsOf: out.appendingPathComponent("index.html"), encoding: .utf8)
        XCTAssertEqual(first, second)
    }

    func testGraphLayoutIsDeterministicAndLayered() throws {
        let tm = try makeMap()
        let cfg = tm.config()
        let surfaces = loadSurfaces(in: cfg.surfacesDir)
        let nodes = layoutGraph(surfaces)
        XCTAssertEqual(nodes["home"]?.col, 0)
        XCTAssertEqual(nodes["cart"]?.col, 1)
    }
}
