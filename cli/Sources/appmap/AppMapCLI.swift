// appmap — App Map CLI. Warn, record, never block: every subcommand exits 0
// unless the CLI itself is misused (bad args / no map found → exit 2).

import AppMapKit
import ArgumentParser
import Foundation

let appmapVersion = "0.2.0"

@main
struct AppMap: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "appmap",
        abstract: "App Map — a living, code-grounded record of an app's surfaces.",
        version: appmapVersion,
        subcommands: [Validate.self]
    )
}

/// Resolve the app-map/ directory from --map or by auto-detection.
func resolveConfig(explicit: String?) throws -> Config {
    let mapDir: URL
    if let explicit {
        mapDir = URL(fileURLWithPath: explicit).standardizedFileURL
    } else if let found = findMapDir() {
        mapDir = found
    } else {
        FileHandle.standardError.write(Data(
            "error: no 'app-map/' found here or above. Pass --map <dir>.\n".utf8
        ))
        throw ExitCode(2)
    }
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: mapDir.path, isDirectory: &isDir),
          isDir.boolValue else {
        FileHandle.standardError.write(Data(
            "error: map dir does not exist: \(mapDir.path)\n".utf8
        ))
        throw ExitCode(2)
    }
    return loadConfig(mapDir: mapDir)
}

struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Report schema violations, broken links, and dead anchors (never fails)."
    )

    @Option(name: .customLong("map"), help: "Path to the app-map/ dir (default: auto-detect).")
    var map: String?

    func run() throws {
        let cfg = try resolveConfig(explicit: map)
        let surfaces = loadSurfaces(in: cfg.surfacesDir)
        let findings = AppMapKit.validate(surfaces, cfg: cfg)

        if findings.isEmpty {
            print("ok: \(surfaces.count) surface(s), no findings.")
            return
        }
        let errors = findings.filter { $0.level == .error }.count
        let warns = findings.count - errors
        for f in findings {
            let level = f.level.rawValue.padding(toLength: 5, withPad: " ", startingAt: 0)
            print("  [\(level)] \(f.surface): \(f.message)")
        }
        print("\n\(surfaces.count) surface(s): \(errors) error-level, \(warns) warn-level finding(s).")
        print("(warn, record, never block — exit 0)")
    }
}
