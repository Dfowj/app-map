// appmap — App Map CLI. Warn, record, never block: every subcommand exits 0
// unless the CLI itself is misused (bad args / no map found → exit 2).

import AppMapKit
import ArgumentParser
import Foundation

let appmapVersion = "0.4.0"

@main
struct AppMap: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "appmap",
        abstract: "App Map — a living, code-grounded record of an app's surfaces.",
        version: appmapVersion,
        subcommands: [Validate.self, Render.self, Stamp.self]
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

struct Render: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Rebuild manifest.yaml and the static site in rendered/ (wholesale)."
    )

    @Option(name: .customLong("map"), help: "Path to the app-map/ dir (default: auto-detect).")
    var map: String?

    func run() throws {
        let cfg = try resolveConfig(explicit: map)
        let surfaces = loadSurfaces(in: cfg.surfacesDir)
        let links = buildLinks(surfaces)

        let manifest = buildManifestYAML(surfaces: surfaces, links: links, cfg: cfg)
        try manifest.write(to: cfg.manifestPath, atomically: true, encoding: .utf8)

        let outDir = try renderMap(surfaces, links: links, cfg: cfg)

        print("rendered \(surfaces.count) surface(s) -> \(outDir.path)")
        print("manifest -> \(cfg.manifestPath.path)")
        let review = surfaces.filter(\.needsReview).map(\.id).sorted()
        if !review.isEmpty {
            print("  review queue: \(review.joined(separator: ", "))")
        }
        for d in links.dangling {
            print("  broken link: \(d.fromID) -> \(d.to) (\(d.kind))")
        }
    }
}

struct Stamp: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: """
        Drift detection for a pre-commit hook: re-stamp last_verified on staged \
        records, flag surfaces whose source changed without their record, patch \
        the manifest, and stage the results. Exits 0 unconditionally.
        """
    )

    @Option(name: .customLong("map"), help: "Path to the app-map/ dir (default: auto-detect).")
    var map: String?

    @Flag(name: .customLong("no-add"), help: "Do not `git add` the files this run modifies.")
    var noAdd = false

    @Option(help: "Override the changed-file set (project-root-relative; default: git staged).")
    var changed: [String] = []

    @Option(help: "Override the sha recorded in last_verified (default: git HEAD short sha).")
    var sha: String?

    func run() throws {
        let cfg = try resolveConfig(explicit: map)

        var changedFiles = Set(changed)
        if changed.isEmpty {
            guard let staged = stagedProjectFiles(cfg: cfg) else {
                print("appmap stamp: not a git repository (or git unavailable) — nothing to do.")
                return  // warn, record, never block
            }
            changedFiles = staged
        }

        let headSHA = sha
            ?? gitOutput(["rev-parse", "--short", "HEAD"], cwd: cfg.projectRoot)
            ?? "initial"
        let date = ISO8601DateFormatter.string(
            from: Date(), timeZone: .current,
            formatOptions: [.withFullDate])

        let result = try AppMapKit.stamp(
            cfg: cfg, changedFiles: changedFiles, sha: headSHA, date: date)

        for note in result.notes {
            print("appmap: WARNING — \(note)")
        }
        if !result.stamped.isEmpty {
            print("appmap: re-stamped last_verified (\(headSHA), \(date)) on: "
                + result.stamped.joined(separator: ", "))
        }
        if result.touchedPaths.isEmpty {
            print("appmap stamp: no drift, nothing to update.")
            return
        }
        if !noAdd {
            _ = gitOutput(["add", "--"] + result.touchedPaths, cwd: cfg.projectRoot)
        }
        print("appmap stamp: updated \(result.touchedPaths.joined(separator: ", "))"
            + (noAdd ? "" : " (staged)"))
    }
}
