// Hermetic temp app-map/ tree builder shared by the test modules. Each test
// gets its own temp directory; the real samples/shopmini tree is never touched.

import Foundation
import XCTest
import Yams

@testable import AppMapKit

/// Repo-root schema/surface.schema.json, located relative to this test file.
let canonicalSchemaURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // AppMapKitTests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()  // cli
    .deletingLastPathComponent()  // repo root
    .appendingPathComponent("schema/surface.schema.json")

final class TempMap {
    let projectRoot: URL
    let mapDir: URL

    init() throws {
        projectRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("appmap-test-\(UUID().uuidString)")
        mapDir = projectRoot.appendingPathComponent("app-map")
        let fm = FileManager.default
        try fm.createDirectory(
            at: mapDir.appendingPathComponent("surfaces"), withIntermediateDirectories: true)
        try fm.createDirectory(
            at: mapDir.appendingPathComponent("schema"), withIntermediateDirectories: true)
        try fm.copyItem(
            at: canonicalSchemaURL,
            to: mapDir.appendingPathComponent("schema/surface.schema.json"))
    }

    deinit {
        try? FileManager.default.removeItem(at: projectRoot)
    }

    func writeConfig(_ fields: [String: Any]) throws {
        let text = try Yams.dump(object: fields)
        try text.write(
            to: mapDir.appendingPathComponent(configName), atomically: true, encoding: .utf8)
    }

    func config() -> Config { loadConfig(mapDir: mapDir) }

    @discardableResult
    func writeSurface(_ id: String, _ frontmatter: [String: Any], body: String = "") throws -> URL {
        let head = try Yams.dump(object: frontmatter)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
        return try writeSurfaceRaw(id, "---\n\(head)\n---\n\(body)")
    }

    @discardableResult
    func writeSurfaceRaw(_ id: String, _ text: String) throws -> URL {
        let dir = mapDir.appendingPathComponent("surfaces/\(id)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("surface.md")
        try text.write(to: path, atomically: true, encoding: .utf8)
        return path
    }

    func loadSurface(_ id: String) throws -> SurfaceRecord {
        try parseSurface(at: mapDir.appendingPathComponent("surfaces/\(id)/surface.md"))
    }

    @discardableResult
    func writeFile(_ relPath: String, _ content: String = "") throws -> URL {
        let path = projectRoot.appendingPathComponent(relPath)
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: path, atomically: true, encoding: .utf8)
        return path
    }

    func validateAll() -> [Finding] {
        let cfg = config()
        return validate(loadSurfaces(in: cfg.surfacesDir), cfg: cfg)
    }
}
