// Drift detection (`appmap stamp`) — line-surgical tier-1 patching plus the
// changed-source-vs-changed-record rules. Tier-3 bytes must never move.

import XCTest

@testable import AppMapKit

final class PatchRecordTextTests: XCTestCase {
    let record = """
    ---
    id: cart
    title: Cart
    kind: tab-root
    states:
      - { name: default, screenshot: screenshot.default.png }
    needs_review: false
    ---

    ## Description

    Prose with --- dashes that must survive.
    """

    func testSetNeedsReviewReplacesOnlyThatLine() throws {
        let patched = try XCTUnwrap(patchRecordText(record, needsReview: true))
        XCTAssertEqual(
            patched,
            record.replacingOccurrences(of: "needs_review: false", with: "needs_review: true"))
    }

    func testFlowStyleYamlAndBodyBytesPreserved() throws {
        let patched = try XCTUnwrap(patchRecordText(record, needsReview: true))
        XCTAssertTrue(patched.contains("- { name: default, screenshot: screenshot.default.png }"))
        XCTAssertTrue(patched.contains("Prose with --- dashes that must survive."))
    }

    func testLastVerifiedAppendedWhenAbsent() throws {
        let patched = try XCTUnwrap(
            patchRecordText(record, lastVerified: (sha: "abc1234", date: "2026-07-13")))
        XCTAssertTrue(patched.contains(
            "needs_review: false\nlast_verified:\n  sha: abc1234\n  date: '2026-07-13'\n---"))
    }

    func testLastVerifiedReplacedWhenPresent() throws {
        let withLV = record.replacingOccurrences(
            of: "needs_review: false",
            with: "last_verified:\n  sha: old0000\n  date: '2020-01-01'\nneeds_review: false")
        let patched = try XCTUnwrap(
            patchRecordText(withLV, lastVerified: (sha: "new1111", date: "2026-07-13")))
        XCTAssertFalse(patched.contains("old0000"))
        XCTAssertFalse(patched.contains("2020-01-01"))
        XCTAssertTrue(patched.contains("last_verified:\n  sha: new1111\n  date: '2026-07-13'"))
        XCTAssertTrue(patched.contains("needs_review: false"))  // neighbor untouched
    }

    func testNeedsReviewAppendedWhenAbsent() throws {
        let noNR = record.replacingOccurrences(of: "needs_review: false\n", with: "")
        let patched = try XCTUnwrap(patchRecordText(noNR, needsReview: true))
        XCTAssertTrue(patched.contains("needs_review: true\n---"))
    }

    func testNoFrontmatterReturnsNil() {
        XCTAssertNil(patchRecordText("plain markdown, no fences", needsReview: true))
    }
}

final class StampRulesTests: XCTestCase {
    private func makeMap() throws -> TempMap {
        let tm = try TempMap()
        try tm.writeConfig(["launch_surface": "cart"])
        try tm.writeFile("Sources/CartView.swift", "struct CartView {}\n")
        try tm.writeSurfaceRaw("cart", """
        ---
        id: cart
        title: Cart
        kind: screen
        code_anchor:
          file: Sources/CartView.swift
          symbol: CartView
        needs_review: false
        ---

        ## Description

        Human prose.
        """)
        return tm
    }

    func testAnchorChangedWithoutRecordFlagsReview() throws {
        let tm = try makeMap()
        let result = try stamp(
            cfg: tm.config(), changedFiles: ["Sources/CartView.swift"],
            sha: "abc1234", date: "2026-07-13")

        XCTAssertEqual(result.flagged, ["cart"])
        XCTAssertTrue(result.stamped.isEmpty)
        let record = try tm.loadSurface("cart")
        XCTAssertTrue(record.needsReview)
        XCTAssertTrue(record.lastVerified.isEmpty)  // not verified, only flagged
        XCTAssertTrue(record.body.contains("Human prose."))

        // manifest picked up the flag
        let manifest = try String(
            contentsOf: tm.mapDir.appendingPathComponent("manifest.yaml"), encoding: .utf8)
        XCTAssertTrue(manifest.contains("review_queue:\n- cart"))
        XCTAssertTrue(result.touchedPaths.contains("app-map/surfaces/cart/surface.md"))
        XCTAssertTrue(result.touchedPaths.contains("app-map/manifest.yaml"))
    }

    func testRecordChangedGetsStamped() throws {
        let tm = try makeMap()
        let result = try stamp(
            cfg: tm.config(),
            changedFiles: ["app-map/surfaces/cart/surface.md", "Sources/CartView.swift"],
            sha: "abc1234", date: "2026-07-13")

        XCTAssertEqual(result.stamped, ["cart"])
        XCTAssertTrue(result.flagged.isEmpty)  // record moved with the source
        let record = try tm.loadSurface("cart")
        XCTAssertEqual(record.lastVerified["sha"] as? String, "abc1234")
        XCTAssertEqual(record.lastVerified["date"] as? String, "2026-07-13")
        XCTAssertFalse(record.needsReview)
    }

    func testUnrelatedChangeTouchesNothing() throws {
        let tm = try makeMap()
        _ = try stamp(  // seed the manifest so the second run is a true no-op
            cfg: tm.config(), changedFiles: [], sha: "abc1234", date: "2026-07-13")
        let result = try stamp(
            cfg: tm.config(), changedFiles: ["Sources/Other.swift"],
            sha: "abc1234", date: "2026-07-13")
        XCTAssertTrue(result.stamped.isEmpty)
        XCTAssertTrue(result.flagged.isEmpty)
        XCTAssertTrue(result.touchedPaths.isEmpty)
    }

    func testAlreadyFlaggedIsNotRewritten() throws {
        let tm = try makeMap()
        _ = try stamp(
            cfg: tm.config(), changedFiles: ["Sources/CartView.swift"],
            sha: "abc1234", date: "2026-07-13")
        let result = try stamp(
            cfg: tm.config(), changedFiles: ["Sources/CartView.swift"],
            sha: "def5678", date: "2026-07-14")
        XCTAssertTrue(result.flagged.isEmpty)
        XCTAssertTrue(result.touchedPaths.isEmpty)
    }

    func testStampedRecordStillValidates() throws {
        let tm = try makeMap()
        _ = try stamp(
            cfg: tm.config(), changedFiles: ["app-map/surfaces/cart/surface.md"],
            sha: "abc1234", date: "2026-07-13")
        let findings = tm.validateAll()
        XCTAssertTrue(findings.isEmpty, "unexpected findings: \(findings.map(\.message))")
    }
}
