// Warning on drift and broken things (validate). Ported from the previous
// iteration's tests/test_validate.py — semantics, not code.

import XCTest

@testable import AppMapKit

final class SchemaFindingsTests: XCTestCase {
    func testBadEnumIsWarn() throws {
        let tm = try TempMap()
        try tm.writeSurface("home", ["id": "home", "title": "Home", "kind": "not-a-kind"])
        let findings = tm.validateAll()
        XCTAssertTrue(findings.contains { $0.level == .warn && $0.message.contains("not one of") })
    }

    func testMissingRequiredIsWarn() throws {
        let tm = try TempMap()
        try tm.writeSurface("home", ["id": "home", "kind": "screen"])  // no title
        let findings = tm.validateAll()
        XCTAssertTrue(findings.contains {
            $0.level == .warn && $0.message.contains("missing required 'title'")
        })
    }

    func testWrongTypeIsWarn() throws {
        let tm = try TempMap()
        try tm.writeSurface(
            "home",
            ["id": "home", "title": "Home", "kind": "screen", "contains": "not-a-list"])
        let findings = tm.validateAll()
        XCTAssertTrue(findings.contains { $0.level == .warn && $0.message.contains("expected array") })
    }

    func testBadIDPatternIsWarn() throws {
        let tm = try TempMap()
        try tm.writeSurface("home", ["id": "Home Screen!", "title": "Home", "kind": "screen"])
        let findings = tm.validateAll()
        XCTAssertTrue(findings.contains { $0.level == .warn && $0.message.contains("does not match") })
    }
}

final class AnchorFindingsTests: XCTestCase {
    func testMissingAnchorFileIsError() throws {
        let tm = try TempMap()
        try tm.writeSurface("home", [
            "id": "home", "title": "Home", "kind": "screen",
            "code_anchor": ["file": "Sources/DoesNotExist.swift"],
        ])
        let findings = tm.validateAll()
        XCTAssertTrue(findings.contains {
            $0.level == .error && $0.message.contains("code_anchor.file missing")
        })
    }

    func testMissingSymbolIsWarn() throws {
        let tm = try TempMap()
        try tm.writeFile("Sources/Foo.swift", "struct Foo {}\n")
        try tm.writeSurface("home", [
            "id": "home", "title": "Home", "kind": "screen",
            "code_anchor": ["file": "Sources/Foo.swift", "symbol": "Bar"],
        ])
        let findings = tm.validateAll()
        XCTAssertTrue(findings.contains {
            $0.level == .warn && $0.message.contains("symbol 'Bar' not found")
        })
    }

    func testSymbolMatchIsWordBounded() throws {
        let tm = try TempMap()
        try tm.writeFile("Sources/Foo.swift", "struct FooBarView {}\n")
        try tm.writeSurface("home", [
            "id": "home", "title": "Home", "kind": "screen",
            "code_anchor": ["file": "Sources/Foo.swift", "symbol": "Foo"],
        ])
        let findings = tm.validateAll()
        XCTAssertTrue(findings.contains {
            $0.level == .warn && $0.message.contains("symbol 'Foo' not found")
        })
    }

    func testAnchorFileAndSymbolPresentNoFinding() throws {
        let tm = try TempMap()
        try tm.writeFile("Sources/Foo.swift", "struct Foo {}\n")
        try tm.writeSurface("home", [
            "id": "home", "title": "Home", "kind": "screen",
            "code_anchor": ["file": "Sources/Foo.swift", "symbol": "Foo"],
        ])
        let findings = tm.validateAll()
        XCTAssertFalse(findings.contains { $0.message.contains("code_anchor") })
    }
}

final class WatchesFindingsTests: XCTestCase {
    func testMissingWatchesFileIsError() throws {
        let tm = try TempMap()
        try tm.writeSurface("home", [
            "id": "home", "title": "Home", "kind": "screen",
            "watches": ["Sources/GoneViewModel.swift"],
        ])
        let findings = tm.validateAll()
        XCTAssertTrue(findings.contains {
            $0.level == .error
                && $0.message.contains("watches file missing: Sources/GoneViewModel.swift")
        })
    }

    func testPresentWatchesFileNoFinding() throws {
        let tm = try TempMap()
        try tm.writeFile("Sources/HomeViewModel.swift", "final class HomeViewModel {}\n")
        try tm.writeSurface("home", [
            "id": "home", "title": "Home", "kind": "screen",
            "watches": ["Sources/HomeViewModel.swift"],
        ])
        let findings = tm.validateAll()
        XCTAssertFalse(findings.contains { $0.message.contains("watches") })
    }
}

final class ScreenshotFindingsTests: XCTestCase {
    func testUnresolvedScreenshotIsWarn() throws {
        let tm = try TempMap()
        try tm.writeSurface("home", [
            "id": "home", "title": "Home", "kind": "screen",
            "states": [["name": "default", "screenshot": "shot.png"]],
        ])
        let findings = tm.validateAll()
        XCTAssertTrue(findings.contains {
            $0.level == .warn && $0.message.contains("screenshot unresolved")
        })
    }

    func testResolvedScreenshotNoFinding() throws {
        let tm = try TempMap()
        try tm.writeSurface("home", [
            "id": "home", "title": "Home", "kind": "screen",
            "states": [["name": "default", "screenshot": "shot.png"]],
        ])
        try tm.writeFile("app-map/surfaces/home/shot.png", "fake-png-bytes")
        let findings = tm.validateAll()
        XCTAssertFalse(findings.contains { $0.message.contains("screenshot unresolved") })
    }

    func testScreenshotDirFromConfigResolves() throws {
        let tm = try TempMap()
        try tm.writeConfig(["screenshot_dirs": ["Snapshots"]])
        try tm.writeSurface("home", [
            "id": "home", "title": "Home", "kind": "screen",
            "states": [["name": "default", "screenshot": "home.png"]],
        ])
        try tm.writeFile("Snapshots/home.png", "fake-png-bytes")
        let findings = tm.validateAll()
        XCTAssertFalse(findings.contains { $0.message.contains("screenshot unresolved") })
    }
}

final class DanglingFindingsTests: XCTestCase {
    func testDanglingEdgeIsError() throws {
        let tm = try TempMap()
        try tm.writeSurface("home", [
            "id": "home", "title": "Home", "kind": "screen",
            "edges": [["id": "e1", "to": "ghost"]],
        ])
        let findings = tm.validateAll()
        XCTAssertTrue(findings.contains {
            $0.level == .error && $0.message.contains("dangling edge -> 'ghost'")
        })
    }

    func testDanglingContainsAndEntryPointAreErrors() throws {
        let tm = try TempMap()
        try tm.writeSurface("home", [
            "id": "home", "title": "Home", "kind": "tab-bar",
            "contains": ["ghost-tab"],
            "entry_points": [["type": "deepLink", "value": "app://x", "to": "ghost-screen"]],
        ])
        let findings = tm.validateAll()
        XCTAssertTrue(findings.contains { $0.message.contains("dangling contains -> 'ghost-tab'") })
        XCTAssertTrue(findings.contains {
            $0.message.contains("dangling entry_point -> 'ghost-screen'")
        })
    }

    func testResolvedLinksNoFindings() throws {
        let tm = try TempMap()
        try tm.writeSurface("home", [
            "id": "home", "title": "Home", "kind": "screen",
            "edges": [["id": "e1", "to": "detail"]],
        ])
        try tm.writeSurface("detail", ["id": "detail", "title": "Detail", "kind": "screen"])
        let findings = tm.validateAll()
        XCTAssertFalse(findings.contains { $0.message.contains("dangling") })
    }
}

final class NeverBlocksTests: XCTestCase {
    func testValidateSurvivesAThoroughlyBrokenMap() throws {
        let tm = try TempMap()
        try tm.writeSurface("home", [
            "id": "home",
            "title": "Home",
            "kind": "not-a-real-kind",
            "code_anchor": ["file": "Sources/Missing.swift"],
            "edges": [["id": "e1", "to": "ghost"]],
            "contains": "not-a-list",
            "states": [["name": "default", "screenshot": "missing.png"]],
        ])
        let findings = tm.validateAll()
        XCTAssertGreaterThan(findings.count, 0)
    }

    func testUnparseableYAMLIsToleratedAsSchemaWarnings() throws {
        let tm = try TempMap()
        try tm.writeSurfaceRaw("bad", "---\n: : : not yaml\n---\nBody survives.\n")
        let findings = tm.validateAll()
        // Empty data → missing required id/title/kind, but no crash.
        XCTAssertTrue(findings.contains { $0.message.contains("missing required") })
    }
}

final class LinkGraphTests: XCTestCase {
    func testIncomingInversion() throws {
        let tm = try TempMap()
        try tm.writeSurface("home", [
            "id": "home", "title": "Home", "kind": "screen",
            "edges": [["id": "to-cart", "to": "cart", "trigger": "Tap cart icon"]],
        ])
        try tm.writeSurface("cart", ["id": "cart", "title": "Cart", "kind": "screen"])
        let surfaces = loadSurfaces(in: tm.config().surfacesDir)
        let links = buildLinks(surfaces)
        let incoming = links.incoming["cart"] ?? []
        XCTAssertEqual(incoming.count, 1)
        XCTAssertEqual(incoming.first?.fromID, "home")
        XCTAssertEqual(incoming.first?.edge["trigger"] as? String, "Tap cart icon")
        XCTAssertTrue(links.incoming["home"]?.isEmpty ?? false)
    }
}
